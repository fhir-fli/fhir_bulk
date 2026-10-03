import 'dart:async';
import 'dart:convert';

import 'package:fhir_bulk/src/bulk_model.dart';
import 'package:fhir_bulk/src/bulk_models.dart';
import 'package:fhir_bulk/src/fhir_bulk.dart';
import 'package:fhir_bulk/src/operation_outcome.dart';
import 'package:fhir_node/fhir_node.dart';
import 'package:http/http.dart';

/// Which resource type, and optionally which one resource, to request in a
/// Bulk Export's `_type`.
class WhichResource {
  /// Creates the request for [resourceType] (`Patient`), or for the one
  /// resource [id] of it.
  const WhichResource(this.resourceType, [this.id]);

  /// The FHIR resource type name (e.g. "Patient", "Observation").
  final String? resourceType;

  /// The optional id of the resource (e.g. "12345").
  final String? id;
}

/// Abstract base class for FHIR Bulk Export requests.
///
/// Supports **both** GET-based calls (default) **and** an optional
/// POST-based mode (if `useHttpPost = true`).
abstract class BulkRequest<R extends FhirNode> {
  /// Constructor for [BulkRequest].
  const BulkRequest({
    required this.model,
    required this.base,
    this.since,
    this.types,
    this.headers,
    this.client,
    this.typeFilters,
    this.outputFormat, // e.g. 'application/fhir+ndjson'
    this.useHttpPost = false,
  });

  /// The version whose resources the export returns.
  final BulkModel<R> model;

  /// The base endpoint (e.g., `https://example.com/fhir`)
  final Uri base;

  /// `_since`, as the instant's text (`2021-01-01T00:00:00Z`): only
  /// resources changed on or after it are included. The Bulk Data IG 2.0.0
  /// OperationDefinition `export` (fetched 2026-10-03) types it `instant`.
  final String? since;

  /// Which resources to include in the export (_type).
  final List<WhichResource>? types;

  /// Additional request headers (e.g. for Auth)
  final Map<String, String>? headers;

  /// Optional custom HTTP client (for mocking or special behavior)
  final Client? client;

  /// The `_typeFilter` parameter(s). E.g.
  /// `['Patient?identifier=foo','Practitioner?name=john']`.
  final List<String>? typeFilters;

  /// The `_outputFormat` parameter. Defaults to `application/fhir+ndjson`.
  final String? outputFormat;

  /// **If true**, do a POST with a Parameters resource
  /// instead of a GET with query params.
  final bool useHttpPost;

  /// Triggers the Bulk Export. Returns the exported resources if
  /// successful, or a list containing one or more OperationOutcome(s) if
  /// there was an error.
  ///
  /// Throws [TimeoutException] if polling exceeds the default timeout
  /// (1 hour) or max attempts (1000).
  Future<List<R>> request() async {
    // Merge in the user's custom headers
    final requestHeaders = <String, String>{
      'prefer': 'respond-async',
      'accept': 'application/fhir+json, application/fhir+ndjson, */*',
    };
    if (headers != null) {
      requestHeaders.addAll(headers!);
    }

    final httpClient = client ?? Client();
    final shouldCloseClient = client == null;
    try {
      // If "useHttpPost" is true, we do a POST with `Parameters`.
      // Otherwise, we do the older GET-based approach.
      late Response initialResponse;
      try {
        if (useHttpPost) {
          initialResponse = await _initiateExportViaPost(
            httpClient,
            requestHeaders,
          );
        } else {
          initialResponse = await _initiateExportViaGet(
            httpClient,
            requestHeaders,
          );
        }
      } on Exception catch (e) {
        return _operationOutcome(
          'Failed to initiate bulk export request',
          diagnostics: e.toString(),
        );
      }

      // Check for immediate error
      if (_errorCodes.containsKey(initialResponse.statusCode)) {
        return _failedHttp(initialResponse.statusCode, initialResponse);
      }

      // Typically, we expect a 202 + Content-Location for async. Some servers
      // might return 200 if the data is small/instant.
      if (initialResponse.statusCode != 202 &&
          initialResponse.statusCode != 200) {
        return _operationOutcome(
          'Unexpected HTTP ${initialResponse.statusCode} from server',
          diagnostics: initialResponse.body,
        );
      }

      if (initialResponse.statusCode == 200) {
        // Possibly an immediate final result
        return await _parseFinalResponse(initialResponse);
      }

      // Otherwise, 202 -> we must poll
      final pollUrl = initialResponse.headers['content-location'];
      if (pollUrl == null) {
        return _operationOutcome(
          'Server returned 202 Accepted but no Content-Location header to '
          'poll.',
        );
      }

      late Response pollResponse;
      try {
        pollResponse = await _pollForCompletion(
          httpClient,
          pollUrl,
          requestHeaders,
        );
      } on Exception catch (e) {
        return _operationOutcome(
          'Failed while polling bulk export status',
          diagnostics: e.toString(),
        );
      }

      if (pollResponse.statusCode ~/ 100 != 2) {
        // 4xx or 5xx
        return _failedHttp(pollResponse.statusCode, pollResponse);
      }

      return await _parseFinalResponse(pollResponse);
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Build the GET URL if useHttpPost=false
  Future<Response> _initiateExportViaGet(
    Client httpClient,
    Map<String, String> headers,
  ) {
    final url = _buildExportUrl();
    return httpClient.get(Uri.parse(url), headers: headers);
  }

  /// Build the POST call with a FHIR Parameters resource if useHttpPost=true
  Future<Response> _initiateExportViaPost(
    Client httpClient,
    Map<String, String> headers,
  ) async {
    final url = _exportEndpoint();
    final body = jsonEncode(_buildParametersResource());

    // ensure content-type is fhir+json
    headers['content-type'] =
        headers['content-type'] ?? 'application/fhir+json';

    return httpClient.post(Uri.parse(url), headers: headers, body: body);
  }

  /// Actually builds the GET query parameters
  String _buildExportUrl() {
    final endpoint = _exportEndpoint();
    final query = <String>[];

    if (outputFormat != null && outputFormat!.isNotEmpty) {
      query.add('_outputFormat=${Uri.encodeQueryComponent(outputFormat!)}');
    }
    if (since != null) {
      // Encoded: an offset's `+` is a space on the wire otherwise
      // (fhirant REVIEW-2026-09-08 row 41).
      query.add('_since=${Uri.encodeQueryComponent(since!)}');
    }
    if (types != null && types!.isNotEmpty) {
      final typeValue = types!
          .map((r) {
            final rt = r.resourceType ?? '';
            return r.id == null ? rt : '$rt/${r.id}';
          })
          .join(',');
      query.add('_type=$typeValue');
    }
    if (typeFilters != null && typeFilters!.isNotEmpty) {
      for (final filter in typeFilters!) {
        query.add('_typeFilter=${Uri.encodeQueryComponent(filter)}');
      }
    }

    final paramString = query.isEmpty ? '' : '?${query.join('&')}';
    return '$endpoint$paramString';
  }

  /// Figures out the base path:
  /// - If BulkRequestGroup => [base]/Group/[id]/$export
  /// - If BulkRequestPatient => [base]/Patient/$export
  /// - Else => [base]/$export (system-level)
  String _exportEndpoint() {
    final baseStr =
        base.toString().endsWith('/')
            ? base.toString().substring(0, base.toString().length - 1)
            : base.toString();

    if (this is BulkRequestGroup<R>) {
      final groupId = (this as BulkRequestGroup<R>).id;
      return '$baseStr/Group/$groupId/\$export';
    } else if (this is BulkRequestPatient<R>) {
      return '$baseStr/Patient/\$export';
    } else {
      return '$baseStr/\$export';
    }
  }

  /// The Parameters resource of a POST kick-off, as JSON. The parameter
  /// types are the Bulk Data IG 2.0.0 OperationDefinition `export`'s
  /// (http://hl7.org/fhir/uv/bulkdata/OperationDefinition/export, fetched
  /// 2026-10-03): `_outputFormat` string, `_since` instant, `_type` string
  /// 0..*, `_typeFilter` string 0..*.
  Map<String, dynamic> _buildParametersResource() {
    final params = <Map<String, dynamic>>[];

    if (outputFormat != null && outputFormat!.isNotEmpty) {
      params.add({'name': '_outputFormat', 'valueString': outputFormat});
    }
    if (since != null) {
      params.add({'name': '_since', 'valueInstant': since});
    }
    if (types != null && types!.isNotEmpty) {
      for (final w in types!) {
        final rtName = w.resourceType;
        if (rtName == null) continue;
        final resourceString = w.id == null ? rtName : '$rtName/${w.id}';
        params.add({'name': '_type', 'valueString': resourceString});
      }
    }
    if (typeFilters != null && typeFilters!.isNotEmpty) {
      for (final tf in typeFilters!) {
        params.add({'name': '_typeFilter', 'valueString': tf});
      }
    }

    return {'resourceType': 'Parameters', 'parameter': params};
  }

  /// Poll until 200 or error
  ///
  /// Throws [TimeoutException] if polling exceeds [timeout] duration
  /// or [maxAttempts] number of attempts.
  Future<Response> _pollForCompletion(
    Client httpClient,
    String pollUrl,
    Map<String, String> headers, {
    Duration? timeout,
    int? maxAttempts,
  }) async {
    final startTime = DateTime.now();
    final timeoutDuration = timeout ?? const Duration(hours: 1);
    var attempts = 0;
    final max = maxAttempts ?? 1000;

    while (attempts < max) {
      if (DateTime.now().difference(startTime) > timeoutDuration) {
        throw TimeoutException(
          'Bulk export polling exceeded timeout of '
          '${timeoutDuration.inHours} hours',
          timeoutDuration,
        );
      }

      final resp = await httpClient.get(Uri.parse(pollUrl), headers: headers);
      if (resp.statusCode ~/ 100 == 2 && resp.statusCode != 202) {
        // 200 or 2xx => done
        return resp;
      }
      if (_errorCodes.containsKey(resp.statusCode) ||
          (resp.statusCode ~/ 100) == 4 ||
          (resp.statusCode ~/ 100) == 5) {
        // error
        return resp;
      }
      // If 202, wait
      final retryAfterStr = resp.headers['retry-after'] ?? '5';
      final retrySeconds = int.tryParse(retryAfterStr) ?? 5;
      await Future<void>.delayed(Duration(seconds: retrySeconds));
      attempts++;
    }

    throw TimeoutException(
      'Bulk export polling exceeded max attempts of $max',
    );
  }

  /// Parse the final 200 response for "output" array, fetch NDJSON
  Future<List<R>> _parseFinalResponse(Response response) async {
    if (response.body.isEmpty) {
      return _operationOutcome('No body returned from final bulk export poll');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      return _operationOutcome(
        'Failed to parse Bulk Export completion response as JSON',
        diagnostics: e.toString(),
      );
    }

    // The `output` array of the complete-status manifest, item by item
    // through BulkExportFile. Item by item rather than the whole body
    // through BulkExportManifest, whose required fields (transactionTime,
    // request, requiresAccessToken, error) a client has no use for here and
    // some servers leave out; a file item without a url is reported and the
    // rest are still fetched.
    final output = decoded['output'] as List<dynamic>? ?? <dynamic>[];
    if (output.isEmpty) {
      // no resources
      return <R>[];
    }

    final results = <R>[];
    final httpClient = client ?? Client();
    final bulk = FhirBulk<R>(model);

    for (final dynamic item in output) {
      final BulkExportFile file;
      try {
        file = BulkExportFile.fromJson(item as Map<String, dynamic>);
      } on Object catch (_) {
        // The server's JSON is not ours: whatever the model rejects.
        results.addAll(
          _operationOutcome(
            'Invalid output item in final response',
            diagnostics: 'Item: $item',
          ),
        );
        continue;
      }
      final url = file.url;
      final uri = Uri.tryParse(url);
      if (uri == null) {
        results.addAll(_operationOutcome('Invalid URL: $url'));
        continue;
      }

      late Response fileResponse;
      try {
        fileResponse = await httpClient.get(uri, headers: headers);
      } on Exception catch (e) {
        results.addAll(
          _operationOutcome(
            'Failed to download $url',
            diagnostics: e.toString(),
          ),
        );
        continue;
      }

      if (_errorCodes.containsKey(fileResponse.statusCode)) {
        results.addAll(_failedHttp(fileResponse.statusCode, fileResponse));
        continue;
      }

      final contentType =
          fileResponse.headers['content-type']?.toLowerCase() ?? '';
      List<R> fileResources;
      final normalizedType = contentType;
      if (normalizedType.contains('zip') ||
          normalizedType.contains('application/zip') ||
          normalizedType.contains('application/x-zip-compressed')) {
        fileResources = await bulk.fromCompressedData(
          'application/zip',
          fileResponse.bodyBytes,
        );
      } else if (normalizedType.contains('gzip') ||
          normalizedType.contains('x-gzip') ||
          normalizedType.contains('application/gzip')) {
        fileResources = await bulk.fromCompressedData(
          'application/gzip',
          fileResponse.bodyBytes,
        );
      } else if (normalizedType.contains('tar') ||
          normalizedType.contains('application/x-tar')) {
        fileResources = await bulk.fromCompressedData(
          'application/x-tar',
          fileResponse.bodyBytes,
        );
      } else {
        // assume NDJSON
        fileResources = bulk.fromNdJson(fileResponse.body);
      }
      results.addAll(fileResources);
    }

    return results;
  }

  /// Creates an OperationOutcome for an HTTP error
  List<R> _failedHttp(int statusCode, Response result) {
    final message = _errorCodes[statusCode] ?? 'Unknown Error';
    return [
      model.fromJson(
        errorOperationOutcomeJson(
          details: 'HTTP $statusCode: $message',
          diagnostics: result.body,
        ),
      ),
    ];
  }

  /// Convenience to create an OperationOutcome for non-HTTP errors
  List<R> _operationOutcome(
    String issue, {
    String? diagnostics,
  }) {
    return [
      model.fromJson(
        errorOperationOutcomeJson(details: issue, diagnostics: diagnostics),
      ),
    ];
  }

  /// Known HTTP error codes -> textual meaning
  static const Map<int, String> _errorCodes = {
    400: 'Bad Request',
    401: 'Not Authorized',
    403: 'Forbidden',
    404: 'Not Found',
    405: 'Method Not Allowed',
    409: 'Conflict',
    412: 'Precondition Failed',
    422: 'Unprocessable Entity',
    500: 'Internal Server Error',
    501: 'Not Implemented',
    503: 'Service Unavailable',
  };
}

/// Export for all patients
class BulkRequestPatient<R extends FhirNode> extends BulkRequest<R> {
  /// Constructor for [BulkRequestPatient].
  const BulkRequestPatient({
    required super.model,
    required super.base,
    super.since,
    super.types,
    super.headers,
    super.client,
    super.typeFilters,
    super.outputFormat,
    super.useHttpPost,
  });
}

/// Export for a specific group
class BulkRequestGroup<R extends FhirNode> extends BulkRequest<R> {
  /// Constructor for [BulkRequestGroup].
  const BulkRequestGroup({
    required super.model,
    required super.base,
    required this.id,
    super.since,
    super.types,
    super.headers,
    super.client,
    super.typeFilters,
    super.outputFormat,
    super.useHttpPost,
  });

  /// The id of the Group to export
  final String id;
}

/// Export for the entire system
class BulkRequestSystem<R extends FhirNode> extends BulkRequest<R> {
  /// Constructor for [BulkRequestSystem].
  const BulkRequestSystem({
    required super.model,
    required super.base,
    super.since,
    super.types,
    super.headers,
    super.client,
    super.typeFilters,
    super.outputFormat,
    super.useHttpPost,
  });
}

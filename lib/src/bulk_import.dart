import 'dart:convert';

import 'package:fhir_bulk/src/bulk_model.dart';
import 'package:fhir_node/fhir_node.dart';
import 'package:http/http.dart';

/// A description of one NDJSON file to be imported.
class ImportFile {
  /// Creates an [ImportFile] with the specified resource type name and URL.
  const ImportFile({
    required this.resourceType,
    required this.url,
  });

  /// The FHIR resource type name stored within this NDJSON file
  /// (e.g. "Patient").
  final String resourceType;

  /// The HTTP(S) location of the NDJSON file.
  final Uri url;
}

/// A class to handle a FHIR Bulk Import (`$import`) request.
///
/// Per HAPI/Smile CDR docs:
/// - POST /$import with a Parameters resource in the body
/// - Must have `Prefer: respond-async`
/// - Body must contain inputFormat = "application/fhir+ndjson", etc.
/// - Each file must be one resourceType only
/// - The server responds with an OperationOutcome. Typically this will
///   contain a job ID in `issue[0].diagnostics`.
///
/// Note: The official specs do not define a standard *polling* URL for import.
class BulkImportRequest<R extends FhirNode> {
  /// Creates a [BulkImportRequest] with the specified parameters.
  ///
  /// Throws [ArgumentError] for an empty [files] list or a file URL that is
  /// not `http` or `https`: a caller's mistake, checked at runtime so it
  /// fails the same way on a device (where asserts are off) as in tests.
  BulkImportRequest({
    required this.model,
    required this.base,
    required this.files,
    this.inputSource,
    this.credentialHttpBasic,
    this.maxBatchResourceCount,
    this.client,
    this.additionalParameters,
  }) {
    if (files.isEmpty) {
      throw ArgumentError.value(files, 'files', 'At least one file');
    }
    for (final f in files) {
      if (!f.url.hasScheme ||
          (f.url.scheme != 'http' && f.url.scheme != 'https')) {
        throw ArgumentError.value(f.url, 'files', 'An HTTP(S) URL');
      }
    }
  }

  /// The version whose OperationOutcome the server's answer is parsed as.
  final BulkModel<R> model;

  /// The server base URL, e.g. https://example.com/fhir
  final Uri base;

  /// The list of NDJSON files to be imported (each has a resourceType + URL).
  final List<ImportFile> files;

  /// Optional "inputSource" - can be used to indicate the base URL for
  /// the FHIR server origin
  final String? inputSource;

  /// Optional HTTP Basic credentials that the server can use to fetch
  /// the NDJSON
  final String? credentialHttpBasic;

  /// Optionally specify the batch size used by the server (HAPI default = 500).
  final int? maxBatchResourceCount;

  /// If you have a custom HTTP client or want to mock calls
  final Client? client;

  /// You can supply additional custom parameters if desired (e.g. extension).
  /// For each key→value, we'll add a
  /// `{"name": key, "valueString": value}` param.
  final Map<String, String>? additionalParameters;

  /// Initiates the Bulk Import by POSTing a FHIR Parameters resource to
  /// `/$import`, returning the server's OperationOutcome
  /// (which typically includes the job ID).
  Future<R> importData() async {
    final httpClient = client ?? Client();

    final body = jsonEncode(_buildParametersResource());

    final headers = <String, String>{
      'Content-Type': 'application/fhir+json',
      'Prefer': 'respond-async',
    };

    late Response response;
    try {
      final importUrl =
          base.toString().endsWith('/') ? '$base\$import' : '$base/\$import';
      final importUri = Uri.tryParse(importUrl);
      if (importUri == null) {
        return _operationOutcome(
          'Invalid base URL: $base',
        );
      }

      response = await httpClient.post(
        importUri,
        headers: headers,
        body: body,
      );
    } on Exception catch (e) {
      return _operationOutcome(
        'Exception during Bulk Import POST',
        diagnostics: e.toString(),
      );
    }

    // If the server responds with e.g. 200 or 202, we expect an
    // OperationOutcome
    if (response.statusCode ~/ 100 != 2) {
      // 4xx or 5xx
      return _failedHttp(response.statusCode, response);
    }

    // Attempt to parse as OperationOutcome
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return model.fromJson(decoded);
    } on Object catch (_) {
      // The server's JSON is not ours: whatever decoding or the model rejects.
      return _operationOutcome(
        'Failed to parse server response as OperationOutcome',
        diagnostics: 'HTTP ${response.statusCode}, body=${response.body}',
      );
    }
  }

  /// Constructs the `Parameters` resource that HAPI (Smile CDR) requires
  /// for `$import`, as JSON.
  Map<String, dynamic> _buildParametersResource() {
    final paramList = <Map<String, dynamic>>[
      // inputFormat
      {'name': 'inputFormat', 'valueCode': 'application/fhir+ndjson'},
    ];

    // inputSource (optional)
    if (inputSource != null && inputSource!.isNotEmpty) {
      paramList.add({'name': 'inputSource', 'valueUri': inputSource});
    }

    // storageDetail
    final storageParts = <Map<String, dynamic>>[
      {'name': 'type', 'valueCode': 'https'},
    ];
    if (credentialHttpBasic != null && credentialHttpBasic!.isNotEmpty) {
      storageParts.add({
        'name': 'credentialHttpBasic',
        'valueString': credentialHttpBasic,
      });
    }
    if (maxBatchResourceCount != null && maxBatchResourceCount! > 0) {
      storageParts.add({
        'name': 'maxBatchResourceCount',
        'valueInteger': maxBatchResourceCount,
      });
    }

    paramList.add({'name': 'storageDetail', 'part': storageParts});

    // input sections, one per file
    for (final file in files) {
      paramList.add({
        'name': 'input',
        'part': [
          {'name': 'type', 'valueCode': file.resourceType},
          {'name': 'url', 'valueUri': file.url.toString()},
        ],
      });
    }

    // Additional parameters, if any
    if (additionalParameters != null && additionalParameters!.isNotEmpty) {
      additionalParameters!.forEach((key, value) {
        paramList.add({'name': key, 'valueString': value});
      });
    }

    return {'resourceType': 'Parameters', 'parameter': paramList};
  }

  /// Creates an OperationOutcome for an HTTP error.
  R _failedHttp(int statusCode, Response result) => model.fromJson(
    errorOperationOutcomeJson(
      details: 'HTTP $statusCode error during Bulk Import',
      diagnostics: result.body,
    ),
  );

  /// Convenience function to create an error OperationOutcome.
  R _operationOutcome(
    String issue, {
    String? diagnostics,
  }) => model.fromJson(
    errorOperationOutcomeJson(details: issue, diagnostics: diagnostics),
  );
}

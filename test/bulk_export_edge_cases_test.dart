import 'dart:convert';

import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/json_node.dart';

void main() {
  group('WhichResource creation and validation', () {
    test('creates WhichResource with resourceType only', () {
      const wr = WhichResource('Patient');
      expect(wr.resourceType, 'Patient');
      expect(wr.id, isNull);
    });

    test('creates WhichResource with resourceType and id', () {
      const wr = WhichResource('Observation', 'obs-123');
      expect(wr.resourceType, 'Observation');
      expect(wr.id, 'obs-123');
    });

    test('creates WhichResource with null resourceType', () {
      const wr = WhichResource(null);
      expect(wr.resourceType, isNull);
      expect(wr.id, isNull);
    });

    test('creates WhichResource with null resourceType and id', () {
      const wr = WhichResource(null, 'some-id');
      expect(wr.resourceType, isNull);
      expect(wr.id, 'some-id');
    });
  });

  group('BulkRequest subclass differences', () {
    test('BulkRequestPatient exports at Patient endpoint', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestPatient(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains(r'Patient/$export'));
      expect(capturedUrl, isNot(contains('Group')));
    });

    test('BulkRequestGroup exports at Group endpoint with id', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestGroup(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        id: 'my-group-42',
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains(r'Group/my-group-42/$export'));
    });

    test('BulkRequestSystem exports at system-level endpoint', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, endsWith(r'$export'));
      expect(capturedUrl, isNot(contains('Patient')));
      expect(capturedUrl, isNot(contains('Group')));
    });

    test('BulkRequestPatient with trailing slash on base', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestPatient(
        model: testModel,
        base: Uri.parse('http://example.com/fhir/'),
        client: mockClient,
      );

      await req.request();
      // Should not have double slash
      expect(capturedUrl, isNot(contains('fhir//Patient')));
      expect(capturedUrl, contains(r'Patient/$export'));
    });
  });

  group('BulkRequest query parameter building', () {
    test('includes _since parameter in GET request', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        since: '2023-06-01T00:00:00Z',
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains('_since=2023-06-01'));
    });

    test('_since with an offset is percent-encoded '
        '(fhirant REVIEW-2026-09-08 row 41)', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        since: '2023-06-01T00:00:00+05:00',
        client: mockClient,
      );

      await req.request();
      // The `+` would be a space on the wire unencoded.
      expect(capturedUrl, contains('_since=2023-06-01T00%3A00%3A00%2B05%3A00'));
      expect(capturedUrl, isNot(contains('+05:00')));
    });

    test('includes _type parameter with multiple types', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        types: const [
          WhichResource('Patient'),
          WhichResource('Observation'),
        ],
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains('_type=Patient,Observation'));
    });

    test('includes _type with resource ID', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        types: const [WhichResource('Patient', '123')],
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains('_type=Patient/123'));
    });

    test('includes _outputFormat parameter', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        outputFormat: 'application/fhir+ndjson',
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains('_outputFormat='));
    });

    test('includes _typeFilter parameters', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        typeFilters: const [
          'Patient?identifier=foo',
          'Practitioner?name=john',
        ],
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains('_typeFilter='));
    });

    test('merges custom headers with defaults', () async {
      Map<String, String>? capturedHeaders;
      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        headers: const {'Authorization': 'Bearer tok123'},
        client: mockClient,
      );

      await req.request();
      expect(capturedHeaders?['prefer'], 'respond-async');
      expect(capturedHeaders?['Authorization'], 'Bearer tok123');
    });
  });

  group('BulkRequest POST-based export', () {
    test('POST sends Parameters resource in body', () async {
      String? capturedBody;
      String? capturedMethod;
      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedBody = request.body;
        return http.Response('', 400);
      });

      final req = BulkRequestPatient(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        useHttpPost: true,
        types: const [WhichResource('Patient')],
        since: '2024-01-01',
        client: mockClient,
      );

      await req.request();
      expect(capturedMethod, 'POST');
      expect(capturedBody, isNotNull);

      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(decoded['resourceType'], 'Parameters');
      final params = decoded['parameter'] as List<dynamic>;
      expect(params, isNotEmpty);

      // Check that _type and _since parameters are present
      final paramNames =
          params.map((p) => (p as Map<String, dynamic>)['name']).toList();
      expect(paramNames, contains('_type'));
      expect(paramNames, contains('_since'));
    });

    test("POST parameter types are the OperationDefinition export's: _since "
        'an instant, the rest strings', () async {
      // http://hl7.org/fhir/uv/bulkdata/OperationDefinition/export 2.0.0,
      // fetched 2026-10-03: _outputFormat string, _since instant, _type
      // string 0..*, _typeFilter string 0..*. The typed client sent _since
      // as valueDateTime.
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response('', 400);
      });

      await BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        useHttpPost: true,
        since: '2024-01-01T00:00:00Z',
        outputFormat: 'application/fhir+ndjson',
        types: const [WhichResource('Patient'), WhichResource('Observation')],
        typeFilters: const ['Patient?active=true'],
        client: mockClient,
      ).request();

      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      final params =
          (decoded['parameter'] as List<dynamic>).cast<Map<String, dynamic>>();
      Map<String, dynamic> named(String name) =>
          params.singleWhere((p) => p['name'] == name);
      expect(named('_since'), {
        'name': '_since',
        'valueInstant': '2024-01-01T00:00:00Z',
      });
      expect(named('_outputFormat')['valueString'], 'application/fhir+ndjson');
      expect(
        params.where((p) => p['name'] == '_type').map((p) => p['valueString']),
        ['Patient', 'Observation'],
      );
      expect(named('_typeFilter')['valueString'], 'Patient?active=true');
    });

    test('POST sets content-type to application/fhir+json', () async {
      Map<String, String>? capturedHeaders;
      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response('', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        useHttpPost: true,
        client: mockClient,
      );

      await req.request();
      expect(capturedHeaders?['content-type'], 'application/fhir+json');
    });
  });

  group('Error response handling during polling', () {
    test('returns OperationOutcome on immediate 400 Bad Request', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Bad Request body', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
      expect(detailsText(result.first), contains('400'));
    });

    test('returns OperationOutcome on 401 Unauthorized', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final req = BulkRequestPatient(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
      expect(detailsText(result.first), contains('401'));
    });

    test('returns OperationOutcome on 500 Internal Server Error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal error', 500);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
    });

    test(
      'returns OperationOutcome on unexpected status code (e.g. 301)',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Moved', 301);
        });

        final req = BulkRequestSystem(
          model: testModel,
          base: Uri.parse('http://example.com/fhir'),
          client: mockClient,
        );

        final result = await req.request();
        expect(result, hasLength(1));
        expect(result.first.fhirType, 'OperationOutcome');
      },
    );

    test('returns OperationOutcome when 202 has no Content-Location', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 202, headers: {});
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
      expect(detailsText(result.first), contains('Content-Location'));
    });

    test(
      'returns OperationOutcome when final response body is empty',
      () async {
        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              '',
              202,
              headers: {
                'content-location': 'http://fake/poll',
              },
            );
          }
          // Poll returns 200 with empty body
          return http.Response('', 200);
        });

        final req = BulkRequestSystem(
          model: testModel,
          base: Uri.parse('http://example.com/fhir'),
          client: mockClient,
        );

        final result = await req.request();
        expect(result, hasLength(1));
        expect(result.first.fhirType, 'OperationOutcome');
      },
    );

    test(
      'returns OperationOutcome when final response is not valid JSON',
      () async {
        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              '',
              202,
              headers: {
                'content-location': 'http://fake/poll',
              },
            );
          }
          return http.Response('this is not json', 200);
        });

        final req = BulkRequestSystem(
          model: testModel,
          base: Uri.parse('http://example.com/fhir'),
          client: mockClient,
        );

        final result = await req.request();
        expect(result, hasLength(1));
        expect(result.first.fhirType, 'OperationOutcome');
      },
    );

    test('returns empty list when output array is empty', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'transactionTime': '2024-01-01T00:00:00Z',
            'output': <dynamic>[],
          }),
          200,
        );
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, isEmpty);
    });

    test('returns OperationOutcome when output item has missing url', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              'transactionTime': '2024-01-01T00:00:00Z',
              'output': [
                {'type': 'Patient'},
              ],
            }),
            200,
          );
        }
        return http.Response('Unexpected', 400);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
    });

    test('returns OperationOutcome when NDJSON download fails', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              'transactionTime': '2024-01-01T00:00:00Z',
              'output': [
                {
                  'type': 'Patient',
                  'url': 'http://fake/patients.ndjson',
                },
              ],
            }),
            200,
          );
        }
        // NDJSON download returns error
        return http.Response('Not Found', 404);
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
    });

    test('handles HTTP exception during kick-off gracefully', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection refused');
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
      expect(diagnostics(result.first), contains('Connection refused'));
    });

    test('handles HTTP exception during polling gracefully', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            '',
            202,
            headers: {
              'content-location': 'http://fake/poll',
            },
          );
        }
        throw Exception('Network timeout');
      });

      final req = BulkRequestSystem(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        client: mockClient,
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'OperationOutcome');
      expect(diagnostics(result.first), contains('Network timeout'));
    });

    test(
      'handles multiple output files with mixed success and failure',
      () async {
        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              jsonEncode({
                'transactionTime': '2024-01-01T00:00:00Z',
                'output': [
                  {
                    'type': 'Patient',
                    'url': 'http://fake/patients.ndjson',
                  },
                  {
                    'type': 'Observation',
                    'url': 'http://fake/observations.ndjson',
                  },
                ],
              }),
              200,
            );
          }
          if (callCount == 2) {
            // First file succeeds
            return http.Response(
              '{"resourceType":"Patient","id":"p1"}',
              200,
              headers: {'content-type': 'application/fhir+ndjson'},
            );
          }
          if (callCount == 3) {
            // Second file fails
            return http.Response('Server Error', 500);
          }
          return http.Response('Unexpected', 400);
        });

        final req = BulkRequestSystem(
          model: testModel,
          base: Uri.parse('http://example.com/fhir'),
          client: mockClient,
        );

        final result = await req.request();
        // Should have the Patient plus an OperationOutcome for the failed file
        expect(result, hasLength(2));
        expect(result[0].fhirType, 'Patient');
        expect(result[1].fhirType, 'OperationOutcome');
      },
    );
  });

  group('BulkImportRequest edge cases', () {
    http.Response ok(http.Request _) => http.Response(
      jsonEncode({
        'resourceType': 'OperationOutcome',
        'issue': [
          {
            'severity': 'information',
            'code': 'informational',
            'diagnostics': 'OK',
          },
        ],
      }),
      202,
    );

    test(
      'an empty files list is an ArgumentError, with asserts or without',
      () {
        // A runtime check, not an assert: it fails the same way on a device.
        expect(
          () => BulkImportRequest(
            model: testModel,
            base: Uri.parse('http://example.com/fhir'),
            files: const [],
          ),
          throwsArgumentError,
        );
      },
    );

    test('a file URL without an http(s) scheme is an ArgumentError', () {
      expect(
        () => BulkImportRequest(
          model: testModel,
          base: Uri.parse('http://example.com/fhir'),
          files: [
            ImportFile(
              resourceType: 'Patient',
              url: Uri.parse('just-a-path/patients.ndjson'),
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => BulkImportRequest(
          model: testModel,
          base: Uri.parse('http://example.com/fhir'),
          files: [
            ImportFile(
              resourceType: 'Patient',
              url: Uri.parse('ftp://data.example.com/patients.ndjson'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('includes additional parameters in POST body', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return ok(request);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        additionalParameters: const {'customParam': 'customValue'},
        client: mockClient,
      );

      await req.importData();
      expect(capturedBody, isNotNull);
      expect(capturedBody, contains('customParam'));
      expect(capturedBody, contains('customValue'));
    });

    test('includes inputSource in POST body when provided', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return ok(request);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        inputSource: 'https://origin-server.example.com/fhir',
        client: mockClient,
      );

      await req.importData();
      expect(capturedBody, contains('inputSource'));
      expect(capturedBody, contains('origin-server.example.com'));
    });

    test('includes maxBatchResourceCount in POST body', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return ok(request);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        maxBatchResourceCount: 1000,
        client: mockClient,
      );

      await req.importData();
      expect(capturedBody, contains('maxBatchResourceCount'));
      expect(capturedBody, contains('1000'));
    });

    test(
      'the POST body is the Parameters shape HAPI reads, key for key',
      () async {
        String? capturedBody;
        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return ok(request);
        });

        await BulkImportRequest(
          model: testModel,
          base: Uri.parse('http://example.com/fhir'),
          files: [
            ImportFile(
              resourceType: 'Patient',
              url: Uri.parse('https://data.example.com/patients.ndjson'),
            ),
          ],
          inputSource: 'https://origin.example.com/fhir',
          credentialHttpBasic: 'user:pass',
          maxBatchResourceCount: 500,
          additionalParameters: const {'extra': 'value'},
          client: mockClient,
        ).importData();

        expect(jsonDecode(capturedBody!), {
          'resourceType': 'Parameters',
          'parameter': [
            {'name': 'inputFormat', 'valueCode': 'application/fhir+ndjson'},
            {
              'name': 'inputSource',
              'valueUri': 'https://origin.example.com/fhir',
            },
            {
              'name': 'storageDetail',
              'part': [
                {'name': 'type', 'valueCode': 'https'},
                {'name': 'credentialHttpBasic', 'valueString': 'user:pass'},
                {'name': 'maxBatchResourceCount', 'valueInteger': 500},
              ],
            },
            {
              'name': 'input',
              'part': [
                {'name': 'type', 'valueCode': 'Patient'},
                {
                  'name': 'url',
                  'valueUri': 'https://data.example.com/patients.ndjson',
                },
              ],
            },
            {'name': 'extra', 'valueString': 'value'},
          ],
        });
      },
    );

    test('handles non-JSON response body gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('plain text not json', 200);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        client: mockClient,
      );

      final result = await req.importData();
      expect(result.fhirType, 'OperationOutcome');
      expect(result.getChildrenByName('issue'), isNotEmpty);
      expect(
        firstIssue(result)?.getChildByName('severity')?.primitiveValue,
        'error',
      );
    });

    test('handles network exception during import', () async {
      final mockClient = MockClient((request) async {
        throw Exception('DNS resolution failed');
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        client: mockClient,
      );

      final result = await req.importData();
      expect(result.fhirType, 'OperationOutcome');
      expect(diagnostics(result), contains('DNS resolution failed'));
    });

    test('sends Prefer: respond-async header', () async {
      Map<String, String>? capturedHeaders;
      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return ok(request);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        client: mockClient,
      );

      await req.importData();
      expect(capturedHeaders?['Prefer'], 'respond-async');
      expect(capturedHeaders?['Content-Type'], 'application/fhir+json');
    });

    test('constructs import URL correctly with trailing slash', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return ok(request);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir/'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        client: mockClient,
      );

      await req.importData();
      expect(capturedUrl, contains(r'$import'));
      // Should not have double slash before $import
      expect(capturedUrl, isNot(contains(r'//$import')));
    });

    test('constructs import URL correctly without trailing slash', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return ok(request);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
        ],
        client: mockClient,
      );

      await req.importData();
      expect(capturedUrl, contains(r'fhir/$import'));
    });

    test('multiple files produce multiple input parameters', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return ok(request);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('https://data.example.com/patients.ndjson'),
          ),
          ImportFile(
            resourceType: 'Observation',
            url: Uri.parse('https://data.example.com/observations.ndjson'),
          ),
          ImportFile(
            resourceType: 'Condition',
            url: Uri.parse('https://data.example.com/conditions.ndjson'),
          ),
        ],
        client: mockClient,
      );

      await req.importData();
      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      final params = decoded['parameter'] as List<dynamic>;

      // Count 'input' parameters
      final inputParams =
          params
              .where(
                (p) => (p as Map<String, dynamic>)['name'] == 'input',
              )
              .toList();
      expect(inputParams, hasLength(3));
    });
  });
}

// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/json_node.dart';

void main() {
  group('Unit Tests for Bulk Export (Mock)', () {
    test(
      'GET-based export handles 202 + polling to 200 + NDJSON download',
      () async {
        // 1) We'll simulate a 202 response with content-location
        //    Then a 200 response with final output
        //    Then NDJSON download
        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            // Kick-off -> 202
            return http.Response(
              '',
              202,
              headers: {
                'content-location': 'http://fake-server/poll',
              },
            );
          } else if (callCount == 2) {
            // Poll -> 200 final
            final bodyJson = jsonEncode(
              {
                'transactionTime': '2023-01-01T00:00:00Z',
                'output': [
                  {
                    'type': 'Patient',
                    'url': 'http://fake-server/exported/patients.ndjson',
                  },
                ],
              },
            );
            return http.Response(bodyJson, 200);
          } else if (callCount == 3) {
            // NDJSON download
            const ndjson = '''
{"resourceType":"Patient","id":"123"}
{"resourceType":"Patient","id":"456"}
''';
            return http.Response(
              ndjson,
              200,
              headers: {
                'content-type': 'application/fhir+ndjson',
              },
            );
          }
          return http.Response('Unexpected', 400);
        });

        final req = BulkRequestPatient(
          model: testModel,
          base: Uri.parse('http://fake-server/fhir'),
          client: mockClient,
        );

        final result = await req.request();
        expect(result, hasLength(2));
        expect(result.first.fhirType, 'Patient');
        expect(idOf(result.first), '123');
      },
    );

    test('POST-based export handles 202 + polling', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          // Kick-off -> 202
          return http.Response(
            '',
            202,
            headers: {
              'content-location': 'http://fake-server/poll',
            },
          );
        } else if (callCount == 2) {
          // Poll -> 200 final
          final bodyJson = jsonEncode(
            {
              'transactionTime': '2023-02-02T00:00:00Z',
              'output': [
                {
                  'type': 'Patient',
                  'url': 'http://fake-server/export/patients.ndjson',
                },
              ],
            },
          );
          return http.Response(bodyJson, 200);
        } else if (callCount == 3) {
          // NDJSON
          const ndjson = '''
{"resourceType":"Patient","id":"abc"}
''';
          return http.Response(
            ndjson,
            200,
            headers: {
              'content-type': 'application/fhir+ndjson',
            },
          );
        }
        return http.Response('Unexpected', 400);
      });

      final req = BulkRequestGroup(
        model: testModel,
        base: Uri.parse('http://fake-server/fhir'),
        id: 'MyGroup',
        client: mockClient,
        useHttpPost: true, // <--- we do POST-based approach
        types: [const WhichResource('Patient')],
      );

      final result = await req.request();
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Patient');
      expect(idOf(result.first), 'abc');
    });
  });

  group('Unit Tests for Bulk Import (Mock)', () {
    test('Import returns OperationOutcome with job ID', () async {
      final mockClient = MockClient((request) async {
        final outcome = {
          'resourceType': 'OperationOutcome',
          'issue': [
            {
              'severity': 'information',
              'code': 'informational',
              'diagnostics': 'Bulk import job started with ID: 1234',
            },
          ],
        };
        return http.Response(jsonEncode(outcome), 202);
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://fake-server/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('http://fake/patients.ndjson'),
          ),
        ],
        client: mockClient,
      );

      final outcome = await req.importData();
      expect(outcome.getChildrenByName('issue'), isNotEmpty);
      expect(diagnostics(outcome), contains('ID: 1234'));
    });
  });

  group('Integration Test Example (REAL)', () {
    // This is just a template. Adjust the URLs and any needed auth tokens
    // for whichever server you want to test (e.g. SMART Bulk Data sandbox).
    //
    // Because the public SMART sandbox might require ephemeral JWKS for auth,
    // you can skip if you have no token or do open endpoints. Or you might try
    // a local HAPI instance where you enabled $export.

    test(
      'Real-world POST-based Group Export (point to a real Bulk Data server)',
      () async {
        // For example, the ephemeral SMART Bulk Data server URL:
        final baseUrl = Uri.parse(
          'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwidGx0IjoxNSwibSI6MSwiZGVsIjowLCJzZWN1cmUiOjB9/fhir',
        );

        // If the server needs auth (JWT), you'd get a token here, e.g.:
        // final token = await getSmartBulkDataToken(...);
        // final headers = {
        //   'Authorization': 'Bearer $token',
        //   'content-type': 'application/fhir+json',
        // };
        // If no auth needed, do minimal headers:
        final headers = {
          'content-type': 'application/fhir+json',
          'accept': 'application/fhir+json',
        };

        final req = BulkRequestGroup(
          model: testModel,
          base: baseUrl,
          id: 'HarvardPilgrimHealthCare',
          headers: headers,
          useHttpPost: true, // do POST
          // Optionally specify resource types
          types: const [
            WhichResource('AllergyIntolerance'),
            WhichResource('Device'),
            WhichResource('ImagingStudy'),
            WhichResource('Patient'),
            WhichResource('DocumentReference'),
            WhichResource('Immunization'),
          ],
        );

        final resources = await req.request();
        print(
          'Got ${resources.length} resources from real server '
          '(or OperationOutcome).',
        );
        for (final r in resources) {
          if (r.fhirType == 'OperationOutcome') {
            print('OperationOutcome: ${diagnostics(r)}');
          } else {
            print('Resource: ${r.fhirType}, id=${idOf(r)}');
          }
        }

        // Just check that it's a list of resources
        // (including possibly OperationOutcomes)
        expect(resources, isA<List<JsonNode>>());
      },
    );
  });
}

import 'dart:convert';

import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/json_node.dart';

void main() {
  group('Bulk Import - Mock Tests', () {
    test('Happy path: 202 response with job ID in OperationOutcome', () async {
      final mockClient = MockClient((request) async {
        final outcome = {
          'resourceType': 'OperationOutcome',
          'issue': [
            {
              'severity': 'information',
              'code': 'informational',
              'diagnostics': 'Bulk import job has been submitted with ID: 1234',
            },
          ],
        };
        return http.Response(jsonEncode(outcome), 202, headers: {});
      });

      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://fake-server/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('http://mysite/patients.ndjson'),
          ),
        ],
        credentialHttpBasic: 'admin:password',
        client: mockClient,
      );
      final oo = await req.importData();
      expect(oo.fhirType, 'OperationOutcome');
      expect(oo.getChildrenByName('issue'), isNotEmpty);
      expect(
        diagnostics(oo),
        contains('job has been submitted with ID: 1234'),
      );
    });

    test('Handles non-2xx response gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });
      final req = BulkImportRequest(
        model: testModel,
        base: Uri.parse('http://fake-server/fhir'),
        files: [
          ImportFile(
            resourceType: 'Patient',
            url: Uri.parse('http://mysite/patients.ndjson'),
          ),
        ],
        client: mockClient,
      );
      final oo = await req.importData();
      expect(oo.getChildrenByName('issue'), isNotEmpty);
      expect(firstIssue(oo)?.getChildByName('code')?.primitiveValue, 'invalid');
      expect(diagnostics(oo), contains('Unauthorized'));
    });
  });
}

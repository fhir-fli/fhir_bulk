import 'dart:convert';

import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:test/test.dart';

import 'ndjson/ndjson.dart';
import 'support/json_node.dart';

void main() {
  const bulk = FhirBulk(testModel);

  group('FhirBulk unit tests', () {
    test('toNdJson and fromNdJson should round-trip a list of Resources', () {
      final resources = [
        resource('Patient', '123'),
        resource('Observation', 'obs1', {
          'status': 'final',
          'code': {
            'coding': [
              {
                'system': 'http://loinc.org',
                'code': '12345-6',
                'display': 'Blood Pressure',
              },
            ],
          },
        }),
      ];

      final ndjson = bulk.toNdJson(resources);
      expect(ndjson.split('\n').length, 2); // 2 lines

      final decoded = bulk.fromNdJson(ndjson);
      expect(decoded.length, 2);
      expect(decoded.first.fhirType, 'Patient');
      expect(decoded.last.fhirType, 'Observation');
      expect(idOf(decoded.first), '123');
      expect(idOf(decoded.last), 'obs1');
    });

    test('toNdJson should handle empty list', () {
      final ndjson = bulk.toNdJson([]);
      expect(ndjson, '');
    });

    test('fromNdJson should ignore empty lines', () {
      const ndjson = '''
{"resourceType":"Patient","id":"123"}

{"resourceType":"Patient","id":"456"}
''';
      final decoded = bulk.fromNdJson(ndjson);
      expect(decoded.length, 2);
    });
  });

  String lines(List<JsonNode> resources) {
    final buffer = StringBuffer();
    for (final resource in resources) {
      buffer.writeln(jsonEncode(testModel.toJson(resource)));
    }
    return buffer.toString().trim();
  }

  group('FHIR Bulk From File/s:', () {
    test('From Accounts ndjson file', () async {
      final resources = await bulk.fromFile('./test/ndjson/Account.ndjson');
      expect(lines(resources), account);
    });

    test('From MedicationRequest ndjson file', () async {
      final resources = await bulk.fromFile(
        './test/ndjson/MedicationRequest.ndjson',
      );
      expect(lines(resources), medicationRequest);
    });
  });

  group('FHIR Bulk From Compressed File/s:', () {
    test('From Accounts zip file', () async {
      final resources = await bulk.fromCompressedFile(
        './test/ndjson/account.zip',
      );
      expect(lines(resources), account);
    });

    test('From MedicationRequest zip file', () async {
      final resources = await bulk.fromCompressedFile(
        './test/ndjson/medicationRequest.zip',
      );
      expect(lines(resources), medicationRequest);
    });

    test('From Accounts & MedicationRequest zip file', () async {
      final resources = await bulk.fromCompressedFile(
        './test/ndjson/accountMedRequest.zip',
      );
      expect(lines(resources), accountMedRequest);
    });

    test('From Account gzip file', () async {
      final resources = await bulk.fromCompressedFile(
        './test/ndjson/Account.ndjson.gz',
      );
      expect(lines(resources), account);
    });

    test('From MedicationRequest gzip file', () async {
      final resources = await bulk.fromCompressedFile(
        './test/ndjson/MedicationRequest.ndjson.gz',
      );
      expect(lines(resources), medicationRequest);
    });

    test('From MedicationRequest tar-gzip file', () async {
      final resources = await bulk.fromCompressedFile(
        './test/ndjson/tarGzip.tar.gz',
      );
      expect(lines(resources), medRequestAccount);
    });
  });

  group('Creating Bulk FHIR String', () {
    test('To Accounts ndjson', () async {
      final resources = bulk.fromNdJson(account);
      final bulkString = bulk.toNdJson(resources);
      expect(bulkString, account);
    });

    test('To MedicationRequest ndjson', () {
      final resources = bulk.fromNdJson(medicationRequest);
      final bulkString = bulk.toNdJson(resources);
      expect(bulkString, medicationRequest);
    });
  });
}

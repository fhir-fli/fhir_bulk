import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:test/test.dart';

import 'support/json_node.dart';

void main() {
  const bulk = FhirBulk(testModel);

  group('NDJSON parsing - malformed lines', () {
    test('fromNdJson throws FormatException on invalid JSON', () {
      const ndjson =
          '{"resourceType":"Patient","id":"1"}\n'
          'this is not valid json\n'
          '{"resourceType":"Patient","id":"2"}';

      expect(
        () => bulk.fromNdJson(ndjson),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'fromNdJson throws FormatException on JSON array instead of object',
      () {
        const ndjson = '[{"resourceType":"Patient","id":"1"}]';

        expect(
          () => bulk.fromNdJson(ndjson),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('fromNdJson throws FormatException on JSON missing resourceType', () {
      const ndjson = '{"id":"1","name":"test"}';

      expect(
        () => bulk.fromNdJson(ndjson),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromNdJson throws FormatException on line with '
        'unrecognized resourceType', () {
      const ndjson = '{"resourceType":"NotARealResource","id":"1"}';

      expect(
        () => bulk.fromNdJson(ndjson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('NDJSON parsing - empty and whitespace input', () {
    test('fromNdJson returns empty list for empty string', () {
      final result = bulk.fromNdJson('');
      expect(result, isEmpty);
    });

    test('fromNdJson returns empty list for whitespace-only string', () {
      final result = bulk.fromNdJson('   \n  \n   ');
      expect(result, isEmpty);
    });

    test('fromNdJson returns empty list for newlines only', () {
      final result = bulk.fromNdJson('\n\n\n');
      expect(result, isEmpty);
    });

    test('toNdJson returns empty string for empty list', () {
      final result = bulk.toNdJson([]);
      expect(result, '');
    });
  });

  group('NDJSON parsing - single resource', () {
    test('fromNdJson parses single Patient without trailing newline', () {
      const ndjson = '{"resourceType":"Patient","id":"only-one"}';
      final result = bulk.fromNdJson(ndjson);
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Patient');
      expect(idOf(result.first), 'only-one');
    });

    test('fromNdJson parses single Patient with trailing newline', () {
      const ndjson = '{"resourceType":"Patient","id":"only-one"}\n';
      final result = bulk.fromNdJson(ndjson);
      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Patient');
    });

    test('toNdJson with single resource produces no trailing newline', () {
      final ndjson = bulk.toNdJson([resource('Patient', 'solo')]);
      expect(ndjson.endsWith('\n'), isFalse);
      expect(ndjson.split('\n'), hasLength(1));
    });
  });

  group('NDJSON - special characters in string fields', () {
    test('round-trips Patient with unicode characters in name', () {
      final patient = resource('Patient', 'unicode-test', {
        'name': [
          {
            'family': "O'Brien",
            'given': ['Renée'],
          },
        ],
      });

      final ndjson = bulk.toNdJson([patient]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      final name = result.first.getChildrenByName('name').first;
      expect(name.getChildByName('family')?.primitiveValue, "O'Brien");
      expect(
        name.getChildrenByName('given').first.primitiveValue,
        'Renée',
      );
    });

    test('round-trips Patient with escaped quotes in text', () {
      final patient = resource('Patient', 'quotes-test', {
        'text': {
          'status': 'generated',
          'div':
              '<div xmlns="http://www.w3.org/1999/xhtml">She said '
              '&quot;hello&quot;</div>',
        },
      });

      final ndjson = bulk.toNdJson([patient]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Patient');
      expect(
        result.first
            .getChildByName('text')
            ?.getChildByName('div')
            ?.primitiveValue,
        contains('hello'),
      );
    });

    test('round-trips Patient with newline in address text', () {
      final patient = resource('Patient', 'newline-addr', {
        'address': [
          {'text': '123 Main St\nApt 4B\nSpringfield, IL'},
        ],
      });

      final ndjson = bulk.toNdJson([patient]);
      // JSON encoding should escape the newline, keeping NDJSON valid
      expect(ndjson.contains(r'\n'), isTrue);

      final result = bulk.fromNdJson(ndjson);
      expect(result, hasLength(1));
      expect(
        result.first
            .getChildrenByName('address')
            .first
            .getChildByName('text')
            ?.primitiveValue,
        contains('Apt 4B'),
      );
    });

    test('round-trips Patient with empty string fields', () {
      final patient = resource('Patient', 'empty-fields', {
        'name': [
          {'family': ''},
        ],
      });

      final ndjson = bulk.toNdJson([patient]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Patient');
    });
  });

  group('NDJSON round-trip - various resource types', () {
    test('round-trips Observation', () {
      final obs = resource('Observation', 'obs-rt', {
        'status': 'final',
        'code': {
          'coding': [
            {
              'system': 'http://loinc.org',
              'code': '29463-7',
              'display': 'Body Weight',
            },
          ],
        },
        'valueQuantity': {
          'value': 85.5,
          'unit': 'kg',
          'system': 'http://unitsofmeasure.org',
          'code': 'kg',
        },
      });

      final ndjson = bulk.toNdJson([obs]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Observation');
      final decoded = result.first;
      expect(idOf(decoded), 'obs-rt');
      expect(decoded.getChildByName('status')?.primitiveValue, 'final');
      expect(
        decoded
            .getChildByName('value')
            ?.getChildByName('value')
            ?.primitiveValue,
        '85.5',
      );
    });

    test('round-trips Condition', () {
      final condition = resource('Condition', 'cond-rt', {
        'subject': {'reference': 'Patient/123'},
        'code': {
          'coding': [
            {
              'system': 'http://snomed.info/sct',
              'code': '73211009',
              'display': 'Diabetes mellitus',
            },
          ],
        },
      });

      final ndjson = bulk.toNdJson([condition]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Condition');
      expect(idOf(result.first), 'cond-rt');
    });

    test('round-trips Practitioner', () {
      final practitioner = resource('Practitioner', 'pract-rt', {
        'active': true,
        'name': [
          {
            'family': 'Smith',
            'given': ['John'],
            'prefix': ['Dr.'],
          },
        ],
      });

      final ndjson = bulk.toNdJson([practitioner]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Practitioner');
      expect(idOf(result.first), 'pract-rt');
      expect(result.first.getChildByName('active')?.primitiveValue, 'true');
    });

    test('round-trips Encounter', () {
      final encounter = resource('Encounter', 'enc-rt', {
        'status': 'finished',
        'class': {
          'system': 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
          'code': 'AMB',
          'display': 'ambulatory',
        },
      });

      final ndjson = bulk.toNdJson([encounter]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      expect(result.first.fhirType, 'Encounter');
      expect(result.first.getChildByName('status')?.primitiveValue, 'finished');
    });

    test('round-trips mixed resource types in single NDJSON', () {
      final resources = [
        resource('Patient', 'p1'),
        resource('Observation', 'o1', {
          'status': 'final',
          'code': {'text': 'test'},
        }),
        resource('Condition', 'c1', {
          'subject': {'reference': 'Patient/p1'},
        }),
        resource('Encounter', 'e1', {
          'status': 'planned',
          'class': {'code': 'AMB'},
        }),
        resource('AllergyIntolerance', 'ai1', {
          'patient': {'reference': 'Patient/p1'},
        }),
      ];

      final ndjson = bulk.toNdJson(resources);
      expect(ndjson.split('\n'), hasLength(5));

      final result = bulk.fromNdJson(ndjson);
      expect(result, hasLength(5));
      expect(result.map((r) => r.fhirType), [
        'Patient',
        'Observation',
        'Condition',
        'Encounter',
        'AllergyIntolerance',
      ]);
    });
  });

  group('NDJSON - lines with leading/trailing whitespace', () {
    test('fromNdJson trims whitespace around valid JSON lines', () {
      const ndjson =
          '  {"resourceType":"Patient","id":"ws1"}  \n'
          '\t{"resourceType":"Patient","id":"ws2"}\t';
      final result = bulk.fromNdJson(ndjson);
      expect(result, hasLength(2));
      expect(idOf(result[0]), 'ws1');
      expect(idOf(result[1]), 'ws2');
    });
  });

  group('NDJSON round-trip - preserves data fidelity', () {
    test('round-trip preserves nested extensions', () {
      final patient = resource('Patient', 'ext-test', {
        'extension': [
          {
            'url': 'http://example.org/fhir/ext/race',
            'valueCodeableConcept': {
              'coding': [
                {
                  'system': 'urn:oid:2.16.840.1.113883.6.238',
                  'code': '2106-3',
                  'display': 'White',
                },
              ],
            },
          },
        ],
      });

      final ndjson = bulk.toNdJson([patient]);
      final result = bulk.fromNdJson(ndjson);

      expect(result, hasLength(1));
      final extensions = result.first.getChildrenByName('extension');
      expect(extensions, hasLength(1));
      expect(
        extensions.first.getChildByName('url')?.primitiveValue,
        'http://example.org/fhir/ext/race',
      );
    });

    test('round-trip produces identical JSON', () {
      final resources = [
        resource('Patient', 'json-id', {
          'active': true,
          'gender': 'male',
          'birthDate': '1990-01-15',
        }),
      ];

      final ndjson1 = bulk.toNdJson(resources);
      final decoded = bulk.fromNdJson(ndjson1);
      final ndjson2 = bulk.toNdJson(decoded);

      expect(ndjson2, ndjson1);
    });

    test('double round-trip is stable', () {
      final resources = [
        resource('Patient', 'stable1'),
        resource('Observation', 'stable2', {
          'status': 'preliminary',
          'code': {'text': 'BP'},
        }),
      ];

      final pass1 = bulk.toNdJson(resources);
      final pass2 = bulk.toNdJson(bulk.fromNdJson(pass1));
      final pass3 = bulk.toNdJson(bulk.fromNdJson(pass2));

      expect(pass2, pass1);
      expect(pass3, pass1);
    });
  });

  group('NDJSON compression round-trip', () {
    test('toZipFile and fromCompressedData round-trip', () async {
      final resources = [
        resource('Patient', 'zip1'),
        resource('Patient', 'zip2'),
      ];

      final ndjson = bulk.toNdJson(resources);
      final zipBytes = await FhirBulk.toZipFile({'patients': ndjson});
      expect(zipBytes, isNotNull);

      final decoded = await bulk.fromCompressedData(
        'application/zip',
        zipBytes!,
      );
      expect(decoded, hasLength(2));
      expect(decoded[0].fhirType, 'Patient');
      expect(decoded[1].fhirType, 'Patient');
    });

    test('toGZipFile and fromCompressedData round-trip', () async {
      final resources = [resource('Patient', 'gz1')];

      final ndjson = bulk.toNdJson(resources);
      final gzBytes = FhirBulk.toGZipFile({'patients': ndjson});
      expect(gzBytes, isNotNull);

      final decoded = await bulk.fromCompressedData(
        'application/gzip',
        gzBytes!,
      );
      expect(decoded, hasLength(1));
      expect(idOf(decoded.first), 'gz1');
    });

    test('toTarGzFile and fromCompressedData round-trip', () async {
      final resources = [
        resource('Patient', 'tar1'),
        resource('Observation', 'tar2', {
          'status': 'final',
          'code': {'text': 'test'},
        }),
      ];

      final ndjsonPatient = bulk.toNdJson([resources[0]]);
      final ndjsonObs = bulk.toNdJson([resources[1]]);
      final tarGzBytes = await FhirBulk.toTarGzFile({
        'patients': ndjsonPatient,
        'observations': ndjsonObs,
      });
      expect(tarGzBytes, isNotNull);

      final decoded = await bulk.fromCompressedData(
        'application/x-tar',
        tarGzBytes!,
      );
      expect(decoded, hasLength(2));
    });

    test(
      'fromCompressedData with unknown content type returns empty',
      () async {
        final result = await bulk.fromCompressedData(
          'application/octet-stream',
          [1, 2, 3],
        );
        expect(result, isEmpty);
      },
    );
  });

  group('NDJSON - large batch', () {
    test('round-trips 100 resources correctly', () {
      final resources = List.generate(
        100,
        (i) => resource('Patient', 'patient-$i'),
      );

      final ndjson = bulk.toNdJson(resources);
      expect(ndjson.split('\n'), hasLength(100));

      final decoded = bulk.fromNdJson(ndjson);
      expect(decoded, hasLength(100));
      for (var i = 0; i < 100; i++) {
        expect(idOf(decoded[i]), 'patient-$i');
      }
    });
  });
}

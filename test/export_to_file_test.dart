import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/json_node.dart';

void main() {
  const bulk = FhirBulk(testModel);

  group('FhirBulk.toZipFile', () {
    test('creates ZIP containing named .ndjson files', () async {
      final ndjson = bulk.toNdJson([
        resource('Patient', 'p1'),
        resource('Patient', 'p2'),
      ]);
      final zipBytes = await FhirBulk.toZipFile({'patients': ndjson});
      expect(zipBytes, isNotNull);
      expect(zipBytes, isNotEmpty);

      // Decode ZIP and verify file names
      final archive = ZipDecoder().decodeBytes(zipBytes!);
      expect(archive.files, hasLength(1));
      expect(archive.files.first.name, 'patients.ndjson');

      // Verify content is valid NDJSON
      final content = utf8.decode(archive.files.first.content as List<int>);
      final resources = bulk.fromNdJson(content);
      expect(resources, hasLength(2));
      expect(idOf(resources[0]), 'p1');
      expect(idOf(resources[1]), 'p2');
    });

    test('creates ZIP with multiple NDJSON files', () async {
      final patientsNdjson = bulk.toNdJson([resource('Patient', 'p1')]);
      final obsNdjson = bulk.toNdJson([
        resource('Observation', 'o1', {
          'status': 'final',
          'code': {'text': 'test'},
        }),
      ]);

      final zipBytes = await FhirBulk.toZipFile({
        'patients': patientsNdjson,
        'observations': obsNdjson,
      });
      expect(zipBytes, isNotNull);

      final archive = ZipDecoder().decodeBytes(zipBytes!);
      expect(archive.files, hasLength(2));
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('patients.ndjson'));
      expect(names, contains('observations.ndjson'));
    });

    test('round-trips through fromCompressedData', () async {
      final resources = [
        resource('Patient', 'rt1'),
        resource('Patient', 'rt2'),
        resource('Patient', 'rt3'),
      ];

      final ndjson = bulk.toNdJson(resources);
      final zipBytes = await FhirBulk.toZipFile({'data': ndjson});
      final decoded = await bulk.fromCompressedData(
        'application/zip',
        zipBytes!,
      );

      expect(decoded, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(idOf(decoded[i]), 'rt${i + 1}');
      }
    });

    test('handles empty NDJSON map', () async {
      final zipBytes = await FhirBulk.toZipFile({});
      expect(zipBytes, isNotNull);
      // Empty archive should still be valid ZIP bytes
      final archive = ZipDecoder().decodeBytes(zipBytes!);
      expect(archive.files, isEmpty);
    });
  });

  group('FhirBulk.toGZipFile', () {
    test('creates GZIP that decompresses to valid NDJSON', () {
      final ndjson = bulk.toNdJson([resource('Patient', 'gz-p1')]);
      final gzBytes = FhirBulk.toGZipFile({'patients': ndjson});
      expect(gzBytes, isNotNull);
      expect(gzBytes, isNotEmpty);

      // Decompress and verify
      final decompressed = utf8.decode(
        const GZipDecoder().decodeBytes(gzBytes!),
      );
      final resources = bulk.fromNdJson(decompressed);
      expect(resources, hasLength(1));
      expect(idOf(resources.first), 'gz-p1');
    });

    test('concatenates multiple NDJSON values with newline', () {
      final gzBytes = FhirBulk.toGZipFile({
        'patients': '{"resourceType":"Patient","id":"1"}',
        'more': '{"resourceType":"Patient","id":"2"}',
      });
      expect(gzBytes, isNotNull);

      final decompressed = utf8.decode(
        const GZipDecoder().decodeBytes(gzBytes!),
      );
      final resources = bulk.fromNdJson(decompressed);
      expect(resources, hasLength(2));
    });

    test('round-trips through fromCompressedData', () async {
      final resources = [resource('Patient', 'gz-rt')];
      final ndjson = bulk.toNdJson(resources);
      final gzBytes = FhirBulk.toGZipFile({'data': ndjson});

      final decoded = await bulk.fromCompressedData(
        'application/gzip',
        gzBytes!,
      );
      expect(decoded, hasLength(1));
      expect(idOf(decoded.first), 'gz-rt');
    });
  });

  group('FhirBulk.toTarGzFile', () {
    test('creates tar.gz with named .ndjson files', () async {
      final ndjson = bulk.toNdJson([resource('Patient', 'tar-p1')]);
      final tarGzBytes = await FhirBulk.toTarGzFile({'patients': ndjson});
      expect(tarGzBytes, isNotNull);
      expect(tarGzBytes, isNotEmpty);

      // Decompress and untar
      final unzipped = const GZipDecoder().decodeBytes(tarGzBytes!);
      final archive = TarDecoder().decodeBytes(unzipped);
      expect(archive.files, hasLength(1));
      expect(archive.files.first.name, 'patients.ndjson');
    });

    test(
      'round-trips through fromCompressedData as application/x-tar',
      () async {
        final resources = [
          resource('Patient', 'trt1'),
          resource('Observation', 'trt2', {
            'status': 'final',
            'code': {'text': 'test'},
          }),
        ];

        final patientNdjson = bulk.toNdJson([resources[0]]);
        final obsNdjson = bulk.toNdJson([resources[1]]);
        final tarGzBytes = await FhirBulk.toTarGzFile({
          'patients': patientNdjson,
          'observations': obsNdjson,
        });

        final decoded = await bulk.fromCompressedData(
          'application/x-tar',
          tarGzBytes!,
        );
        expect(decoded, hasLength(2));
        expect(decoded[0].fhirType, 'Patient');
        expect(decoded[1].fhirType, 'Observation');
      },
    );
  });

  group('BulkRequestGroup URL building', () {
    test('includes Group/<id> in export URL', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestGroup(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        id: 'group-42',
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains(r'Group/group-42/$export'));
    });

    test('includes query params along with group endpoint', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response('', 400);
      });

      final req = BulkRequestGroup(
        model: testModel,
        base: Uri.parse('http://example.com/fhir'),
        id: 'grp-99',
        types: [const WhichResource('Patient')],
        since: '2024-06-01',
        client: mockClient,
      );

      await req.request();
      expect(capturedUrl, contains(r'Group/grp-99/$export'));
      expect(capturedUrl, contains('_type=Patient'));
      expect(capturedUrl, contains('_since=2024-06-01'));
    });
  });
}

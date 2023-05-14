// ignore_for_file: invalid_annotation_target

// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:fhir/r4.dart';
import 'package:fhir_bulk/r4.dart';
import 'package:test/test.dart';

// Project imports:
import 'ndjson/Account.dart';
import 'ndjson/MedicationRequest.dart';
import 'ndjson/accountMedRequest.dart';
import 'ndjson/medRequestAccount.dart';

void compressTest() {
  group('FHIR Bulk From File/s:', () {
    test('From Accounts ndjson file', () async {
      final List<Resource> resources =
          await FhirBulk.fromFile('./test/ndjson/Account.ndjson');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, account);
    });

    test('From MedicationRequest ndjson file', () async {
      final List<Resource> resources =
          await FhirBulk.fromFile('./test/ndjson/MedicationRequest.ndjson');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, medicationRequest);
    });
  });

  group('FHIR Bulk From Compressed File/s:', () {
    test('From Accounts zip file', () async {
      final List<Resource> resources =
          await FhirBulk.fromCompressedFile('./test/ndjson/account.zip');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, account);
    });

    test('From MedicationRequest zip file', () async {
      final List<Resource> resources = await FhirBulk.fromCompressedFile(
          './test/ndjson/medicationRequest.zip');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, medicationRequest);
    });

    test('From Accounts & MedicationRequest zip file', () async {
      final List<Resource> resources = await FhirBulk.fromCompressedFile(
          './test/ndjson/accountMedRequest.zip');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, accountMedRequest);
    });

    test('From Account gzip file', () async {
      final List<Resource> resources =
          await FhirBulk.fromCompressedFile('./test/ndjson/Account.ndjson.gz');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, account);
    });

    test('From MedicationRequest gzip file', () async {
      final List<Resource> resources = await FhirBulk.fromCompressedFile(
          './test/ndjson/MedicationRequest.ndjson.gz');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, medicationRequest);
    });

    test('From MedicationRequest tar-gzip file', () async {
      final List<Resource> resources =
          await FhirBulk.fromCompressedFile('./test/ndjson/tarGzip.tar.gz');
      String stringList = '';
      for (final Resource resource in resources) {
        stringList += '\n${jsonEncode(resource.toJson())}';
      }
      stringList = stringList.replaceFirst('\n', '');
      expect(stringList, medRequestAccount);
    });
  });

  group('Creating Bulk FHIR String', () {
    test('To Accounts ndjson', () async {
      final List<Resource> resources = FhirBulk.fromNdJson(account);
      final List<Resource> resourceList = <Resource>[];
      resources.forEach(resourceList.add);
      final String bulkString = FhirBulk.toNdJson(resourceList);
      expect(bulkString, account);
    });

    test('To MedicationRequest ndjson', () {
      final List<Resource> resources = FhirBulk.fromNdJson(medicationRequest);
      final List<Resource> resourceList = <Resource>[];
      resources.forEach(resourceList.add);
      final String bulkString = FhirBulk.toNdJson(resourceList);
      expect(bulkString, medicationRequest);
    });
  });
}

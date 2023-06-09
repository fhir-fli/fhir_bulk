// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:fhir/r4.dart';
import 'package:fhir_bulk/r4.dart';

Future<void> main() async {
  await compressTest();
  await requestTest();
}

Future<void> compressTest() async {
  List<Resource> resources =
      await FhirBulk.fromFile('./test/ndjson/Account.ndjson');
  String stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');

  resources = await FhirBulk.fromFile('./test/ndjson/MedicationRequest.ndjson');
  stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');

  resources = await FhirBulk.fromCompressedFile('./test/ndjson/account.zip');
  stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');

  resources =
      await FhirBulk.fromCompressedFile('./test/ndjson/medicationRequest.zip');
  stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');

  resources =
      await FhirBulk.fromCompressedFile('./test/ndjson/accountMedRequest.zip');
  stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');

  resources =
      await FhirBulk.fromCompressedFile('./test/ndjson/Account.ndjson.gz');
  stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');

  resources = await FhirBulk.fromCompressedFile(
      './test/ndjson/MedicationRequest.ndjson.gz');
  stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');

  resources = await FhirBulk.fromCompressedFile('./test/ndjson/tarGzip.tar.gz');
  stringList = '';
  for (final Resource resource in resources) {
    stringList += '\n${jsonEncode(resource.toJson())}';
  }
  stringList = stringList.replaceFirst('\n', '');
}

Future<void> requestTest() async {
  kTestMode = true;

  BulkRequest request =
      BulkRequest.patient(base: Uri.parse('http://hapi.fhir.org/baseR4'));
  List<Resource?> response =
      await request.request(headers: <String, String>{'test': 'header'});

  request = BulkRequest.patient(
      base: Uri.parse('http://hapi.fhir.org/baseR4'),
      types: <WhichResource>[
        WhichResource(R4ResourceType.AllergyIntolerance, null),
        WhichResource(R4ResourceType.Medication, null),
        WhichResource(R4ResourceType.Immunization, null),
      ]);
  response = await request.request(headers: <String, String>{'test': 'header'});

  request = BulkRequest.patient(
      base: Uri.parse('http://hapi.fhir.org/baseR4'),
      types: <WhichResource>[
        WhichResource(R4ResourceType.Practitioner, FhirId('abcdef')),
        WhichResource(R4ResourceType.Organization, FhirId('ghijkl')),
      ]);
  response = await request.request(headers: <String, String>{'test': 'header'});

  request = BulkRequest.patient(
      base: Uri.parse('http://hapi.fhir.org/baseR4'),
      since: FhirDateTime('2021-01-01'),
      types: <WhichResource>[
        WhichResource(R4ResourceType.Practitioner, FhirId('abcdef')),
        WhichResource(R4ResourceType.Organization, FhirId('ghijkl')),
      ]);
  response = await request.request(headers: <String, String>{'test': 'header'});

  request = BulkRequest.group(
    base: Uri.parse('http://hapi.fhir.org/baseR4'),
    id: FhirId('12345'),
  );
  response = await request.request(headers: <String, String>{'test': 'header'});

  request = BulkRequest.system(base: Uri.parse('http://hapi.fhir.org/baseR4'));
  response = await request.request(headers: <String, String>{'test': 'header'});

  request = BulkRequest.patient(
      base: Uri.parse(
          'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwLCJkdXIiOjEwLCJ0bHQiOjE1LCJtIjoxLCJzdHUiOjQsImRlbCI6MH0/fhir'),
      types: <WhichResource>[
        WhichResource(R4ResourceType.AllergyIntolerance, null),
        WhichResource(R4ResourceType.Device, null),
      ]);
  response = await request.request(headers: <String, String>{'test': 'header'});
  String fileString = '';
  for (final Resource? res in response) {
    fileString += jsonEncode(res?.toJson());
  }
  print(fileString);
}

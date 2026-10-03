# fhir_bulk

[![pub package](https://img.shields.io/pub/v/fhir_bulk.svg)](https://pub.dev/packages/fhir_bulk)

FHIR Bulk Data Access for every FHIR version: NDJSON as lists and as streams,
compressed bulk files (zip, gz, tar.gz), the `$export` client with the
[Bulk Data Access IG 2.0.0](https://hl7.org/fhir/uv/bulkdata/STU2/) kick-off
and manifest shapes, and the `$import` client HAPI reads.

FHIR® is the registered trademark of HL7 and is used with the permission of
HL7. Use of the FHIR trademark does not constitute endorsement of this product
by HL7.

## How it is version-free

Resources are read by element name through the
[`fhir_node`](https://pub.dev/packages/fhir_node) contract and built through a
`BulkModel<R>` that a version's binding supplies: its FHIR version, its
resource type names, and a resource from and to JSON. The bindings are
`fhir_r4_bulk`, `fhir_r5_bulk` and `fhir_r6_bulk`; each re-exports this
package with its model filled in, so an application on one version writes
`FhirBulk.fromNdJson(text)` and gets that version's resources.

## Usage with a binding

```dart
import 'package:fhir_r4_bulk/fhir_r4_bulk.dart';

final resources = FhirBulk.fromNdJson(ndjsonText);     // List<Resource>
final text = FhirBulk.toNdJson(resources);

// Streams: one resource a line, never a whole file in memory.
final stream = NdjsonStream.resources(NdjsonStream.lines(file.openRead()));
await NdjsonStream.write(NdjsonStream.encode(stream), sink, flush: sink.flush);

// $export, polled to completion, every output file fetched and decoded.
final exported = await BulkRequestPatient(
  base: Uri.parse('https://example.com/fhir'),
  types: [WhichResource(R4ResourceType.Patient)],
  since: '2024-01-01T00:00:00Z'.toFhirDateTime,
).request();

// $import (HAPI / Smile CDR).
final outcome = await BulkImportRequest(
  base: Uri.parse('https://example.com/fhir'),
  files: [
    ImportFile(
      resourceType: R4ResourceType.Patient,
      url: Uri.parse('https://data.example.com/patients.ndjson'),
    ),
  ],
).importData();
```

## Usage without a binding

Supply a `BulkModel` for whatever implements `FhirNode`:

```dart
import 'package:fhir_bulk/fhir_bulk.dart';

class MyModel extends BulkModel<MyResource> { ... }

const bulk = FhirBulk(MyModel());
final resources = bulk.fromNdJson(text);
```

## Server-side shapes

`BulkExportKickoff.fromQuery` / `.fromParameters` read a kick-off request
(repeated and comma-delimited values become one list, as export.html
requires), `TypeFilter` parses a `_typeFilter` query and names the response
parameters it must not carry, and `BulkExportManifest` is the complete-status
body, checked against the specification's own example.

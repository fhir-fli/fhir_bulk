# fhir_bulk

## [0.13.0]

- One Bulk Data package for every FHIR version, revived from the 2024
  `fhir_bulk` (which carried a copy per version over the old `fhir`
  package). The code is fhir_r4_bulk 0.12.0's, which was byte-identical in
  fhir_r5_bulk and fhir_r6_bulk but for the resource-type enum; those three
  become bindings over this package.
- A binding supplies one `BulkModel<R>`: its version, its resource type
  names, and a resource from and to JSON. Everything else reads resources
  by element name through `fhir_node`: `FhirBulk<R>` and `NdjsonStream<R>`
  are instances over a model (the archive helpers and the text streams
  stay static), `BulkRequest<R>` returns `List<R>`, `BulkImportRequest<R>`
  returns the server's OperationOutcome as `R`,
  `BulkExportKickoff.fromParameters` takes any `FhirNode` Parameters,
  `unknownTypes(model)` and `TypeFilter.resourceTypeKnown(model)` take
  the model. `WhichResource` and `ImportFile` name the resource type as a
  string; `BulkRequest.since` and `BulkRequestGroup.id` are strings.
- `errorOperationOutcomeJson`: the one error-issue OperationOutcome shape,
  as JSON.
- A POST kick-off sends `_since` as `valueInstant`: the Bulk Data IG 2.0.0
  OperationDefinition `export` types it `instant` (the typed client sent
  `valueDateTime`). `_outputFormat`, `_type` and `_typeFilter` stay
  `valueString`.
- `BulkImportRequest` rejects an empty file list or a non-HTTP(S) file URL
  with `ArgumentError` at runtime; they were asserts, which a release
  build does not run.
- No dependency on any fhir_r* package. `BulkModel` is fhir_node 0.6.1's
  `ResourceModel`, and `errorOperationOutcomeJson` is re-exported from there.

## Carried from fhir_r4_bulk

## [Unreleased in fhir_r4_bulk]

- **Streaming NDJSON: `NdjsonStream.lines` (from a byte stream, chunked anyhow), `resources`, `encode` and `write` (to a sink, flushing every N lines).** The list-shaped `FhirBulk` helpers stay; they hold a whole file, which a server export cannot (fhirant REVIEW-2026-09-06 finding 34: 813k Observations as a list 5.1 GB, streamed 741 MB).
- **Bulk Data Access IG 2.0.0 models a client and a server both read**: `BulkExportKickoff` (from a query map or a POSTed `Parameters`; repeated and comma-delimited values are one list, as export.html requires), `TypeFilter`, `BulkExportFile`, `BulkExportManifest` (checked against export.html's own example response body), `bulkOutputFormats`. The client now reads the complete-status body through `BulkExportManifest`.

## The 2024 fhir_bulk, over the `fhir` package

## [0.12.0]

* Updated dependencies

## [0.11.5]

* Fixed it so it actually does convert ndjson into .zip, .gz, or .tar.gz files
* Added this ability for dstu2, stu3, r4 and r5

## [0.11.4]

* Added ability to convert ndjson into .zip, .gz, or .tar.gz files

## [0.11.3]

* updated dependencies

## [0.11.2]

* updated dependencies

## [0.11.1]

* updated dependencies

## [0.11.0]

* Dart 3.0.0!

## [0.10.0]

* Updated dependencies
* Changed some type casting

## [0.9.5]

* Updated dependencies
* Made some factories const

## [0.9.4]

* Updated to fhir 0.9.4
* Updated to Dart 2.19.0

## [0.9.3]

* Updated dependencies

## [0.9.2]

* Updated dependencies

## [0.9.1]

* Updated dependencies

## [0.9.0]

* Updated dependencies
* FHIR 0.9.0

## [0.8.0]

* Updated dependencies
* FHIR 0.8.0
* Dart 2.17.0

## [0.7.0]

* Updated dependencies
* FHIR 0.7.0
* Freezed 2.0.0

## [0.6.1]

* Updated dependencies
* Now FHIR 0.6.2
* Import sorter

## [0.6.0]

* Updated dependencies
* Updated to stable-ish 0.6.0

## [0.5.0-8]

* Updated dependencies

## [0.5.0-7]

* Added lots of comments
* changed function fromData to fromNdJson
* Will probably add ability to compress data with next release (currently only accepts compressed data but not produces it)

## [0.5.0-6]

* FHIR package update
* Freezed 1.0.0

## [0.5.0-5]

* Forgot to update something from fhir

## [0.5.0-4]

* Updated dependencies

* Fixed an issue with one of the tests

## [0.5.0-3]

* Updated dependencies

## [0.5.0-2]

* Updated to Dart 2.14.0

## [0.5.0-1]

* Updated dart version
* Added anlyzer to dev_dependencies
* Not sure why pub.dev cant' run dartanalyzer

## [0.4.4]

* Updated dart version
* Added anlyzer to dev_dependencies
* Not sure why pub.dev cant' run dartanalyzer

## [0.4.3]

* Updated version numbers
* Updated dependencies
* Reran code gen

## [0.4.2]

* Updated to universal I/O so it would run in js

## [0.4.1]

* Changed description since I had copied it from auth.

## [0.4.0]

* Removed dartz dependency
* Included new WhichResource class (just takes the place of Tuple2 I was using)
* Null safe!

## [0.3.0-nullsafety.2]

* Updated dependencies
* Still prerelease because not all dependencies are stable

## [0.3.0-nullsafety.1]

* Added web support

## [0.3.0-nullsafety.0]

* Null safety!
* Should be completely ready for null safety
* Should generally work the same as previously, you'll just need to follow null safety requirements

## [0.2.1]

* added documentation

## [0.2.0]

* Initia publication (2021-02-09)
* Recommended for development purposes to work with the ONC guidelines
* Allows calls for Bulk FHIR downloads - will return a list of Resource Objects
* Multiple methods for dealing with reconstructing objects from data
* Allows data to be passed directly, or as files
* Files may be compressed as ```.zip```, ```.gz```, or ```.tar.gz``` (may add others later)

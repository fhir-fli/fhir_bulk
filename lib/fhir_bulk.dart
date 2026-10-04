/// FHIR Bulk Data Access for every FHIR version: NDJSON as lists and as
/// streams, compressed bulk files, the `$export` client and manifest
/// shapes, and the `$import` client.
///
/// Resources are read through the `fhir_node` contract and built through a
/// [BulkModel] that a version's binding supplies (`fhir_r4_bulk`,
/// `fhir_r5_bulk`, `fhir_r6_bulk`); nothing here depends on a FHIR version.
library;

export 'package:fhir_node/fhir_node.dart'
    show ResourceModel, errorOperationOutcomeJson;

export 'src/bulk_export.dart';
export 'src/bulk_import.dart';
export 'src/bulk_model.dart';
export 'src/bulk_models.dart';
export 'src/fhir_bulk.dart';
export 'src/ndjson_stream.dart';

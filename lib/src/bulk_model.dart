import 'package:fhir_node/fhir_node.dart';

/// What the bulk-data code needs from a FHIR version: fhir_node's
/// [ResourceModel], supplied by a binding (`fhir_r4_bulk`, `fhir_r5_bulk`,
/// `fhir_r6_bulk`). [R] is the binding's resource type (`fhir_r4`'s
/// `Resource`).
typedef BulkModel<R extends FhirNode> = ResourceModel<R>;

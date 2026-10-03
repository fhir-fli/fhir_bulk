import 'package:fhir_node/fhir_node.dart';

/// What the bulk-data code needs from a FHIR version, supplied by a binding
/// (`fhir_r4_bulk`, `fhir_r5_bulk`, `fhir_r6_bulk`).
///
/// [R] is the binding's resource type (a [FhirNode]: `fhir_r4`'s
/// `Resource`). The code here reads a resource by element name through
/// [FhirNode] and never constructs one: a resource comes from JSON through
/// [fromJson] and goes back through [toJson], and that is all a version has
/// to say about itself.
abstract class BulkModel<R extends FhirNode> {
  /// Creates a model.
  const BulkModel();

  /// The version's FHIR version string, `4.3.0`.
  String get fhirVersion;

  /// The resource type names of this version, for `_type` and
  /// `_typeFilter` checks.
  Set<String> get resourceTypeNames;

  /// Parses a resource from its JSON. Throws (whatever the model throws)
  /// when [json] is not a resource of this version.
  R fromJson(Map<String, dynamic> json);

  /// The JSON of [resource].
  Map<String, dynamic> toJson(R resource);
}

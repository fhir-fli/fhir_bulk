import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:fhir_node/fhir_node.dart';

export 'package:fhir_node/fhir_node.dart' show JsonNode;

/// The test model: a fixed set of resource type names, JSON in and out.
/// [fromJson] rejects what is not a resource of the model the way a
/// version's `Resource.fromJson` does (by throwing).
class TestModel extends BulkModel<JsonNode> {
  const TestModel();

  @override
  String get fhirVersion => 'test';

  @override
  Set<String> get resourceTypeNames => const {
    'Account',
    'AllergyIntolerance',
    'Bundle',
    'Condition',
    'Device',
    'DocumentReference',
    'Encounter',
    'Group',
    'ImagingStudy',
    'Immunization',
    'MedicationRequest',
    'Observation',
    'OperationOutcome',
    'Parameters',
    'Patient',
    'Practitioner',
  };

  @override
  JsonNode fromJson(Map<String, dynamic> json) {
    final type = json['resourceType'];
    if (type is! String || !resourceTypeNames.contains(type)) {
      throw FormatException('Not a resource of this model', json);
    }
    return JsonNode.resource(json);
  }

  @override
  Map<String, dynamic> toJson(JsonNode resource) => resource.json;
}

const testModel = TestModel();

/// A resource of [type] with [id] and whatever else [more] carries.
JsonNode resource(
  String type,
  String id, [
  Map<String, dynamic> more = const {},
]) => testModel.fromJson({'resourceType': type, 'id': id, ...more});

/// The `id` of [r], read by name.
String? idOf(FhirNode r) => r.getChildByName('id')?.primitiveValue;

/// The first issue of an OperationOutcome, read by name.
FhirNode? firstIssue(FhirNode oo) => oo.getChildrenByName('issue').firstOrNull;

/// `issue[0].details.text` of an OperationOutcome.
String? detailsText(FhirNode oo) =>
    firstIssue(
      oo,
    )?.getChildByName('details')?.getChildByName('text')?.primitiveValue;

/// `issue[0].diagnostics` of an OperationOutcome.
String? diagnostics(FhirNode oo) =>
    firstIssue(oo)?.getChildByName('diagnostics')?.primitiveValue;

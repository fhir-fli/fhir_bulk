import 'dart:convert';

import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:fhir_node/fhir_node.dart';

/// A [FhirNode] over plain JSON, for the core's own tests: no FHIR version
/// is linked. A map is an element whose type is its `resourceType` or the
/// key it hangs under, a list is a repeat, a primitive is its string. A
/// choice element is found by its prefix: `value` finds `valueReference`.
class JsonNode implements FhirNode {
  JsonNode(this.value, this.fhirType);

  /// A resource from its JSON map.
  factory JsonNode.resource(Map<String, dynamic> json) =>
      JsonNode(json, json['resourceType']! as String);

  final Object? value;

  @override
  final String fhirType;

  /// The map this node is, for a resource or a complex element.
  Map<String, dynamic> get json => value! as Map<String, dynamic>;

  @override
  bool get isPrimitive => value is! Map && value is! List;

  @override
  bool get isResource => value is Map && json.containsKey('resourceType');

  @override
  String? get primitiveValue => isPrimitive ? value?.toString() : null;

  @override
  bool hasType(List<String> names) =>
      names.any((n) => n.toLowerCase() == fhirType.toLowerCase());

  @override
  bool isEmpty() => value == null;

  @override
  bool get isMetadataBased => false;

  @override
  bool equalsDeep(covariant FhirNode? other) =>
      other is JsonNode && jsonEncode(value) == jsonEncode(other.value);

  @override
  List<String> listChildrenNames() =>
      value is Map ? json.keys.toList() : const [];

  @override
  FhirNode? getChildByName(String name) {
    final all = getChildrenByName(name);
    if (all.length > 1) throw StateError('more than one child for $name');
    return all.isEmpty ? null : all.first;
  }

  @override
  List<FhirNode> getChildrenByName(String name, [bool checkValid = false]) {
    if (value is! Map) return const [];
    var v = json[name];
    var type = name;
    if (v == null) {
      for (final key in json.keys) {
        if (key.startsWith(name) &&
            key.length > name.length &&
            key[name.length].toUpperCase() == key[name.length]) {
          v = json[key];
          type = key.substring(name.length);
          break;
        }
      }
    }
    if (v == null) return const [];
    JsonNode node(Object? e) => JsonNode(
      e,
      e is Map<String, dynamic> && e['resourceType'] is String
          ? e['resourceType'] as String
          : type,
    );
    if (v is List) return [for (final e in v) node(e)];
    return [node(v)];
  }
}

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

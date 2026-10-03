import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:fhir_bulk/src/bulk_model.dart';
import 'package:fhir_bulk/src/file_support_stub.dart'
    if (dart.library.io) 'package:fhir_bulk/src/file_support_io.dart';
import 'package:fhir_node/fhir_node.dart';
import 'package:mime/mime.dart';

/// Transformations between NDJSON and FHIR resources of one version, and
/// compressed NDJSON files. The resources are [model]'s; the archive
/// helpers ([toZipFile], [toGZipFile], [toTarGzFile]) take NDJSON text and
/// need no model.
class FhirBulk<R extends FhirNode> {
  /// Creates the helpers over [model].
  const FhirBulk(this.model);

  /// The version whose resources these are.
  final BulkModel<R> model;

  /// Accepts a list of resources and returns them as a single NDJSON string.
  ///
  /// Returns an empty string if [resources] is empty.
  String toNdJson(List<R> resources) {
    final buffer = StringBuffer();
    for (final resource in resources) {
      buffer.writeln(jsonEncode(model.toJson(resource)));
    }
    final result = buffer.toString();
    // Remove trailing newline if present
    return result.endsWith('\n')
        ? result.substring(0, result.length - 1)
        : result;
  }

  /// Accepts an NDJSON-formatted string and converts it into a list of
  /// resources.
  ///
  /// Throws [FormatException] if any line contains invalid JSON or
  /// cannot be parsed as a FHIR Resource.
  List<R> fromNdJson(String content) {
    final lines = content.split('\n');
    final resources = <R>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        try {
          final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
          resources.add(model.fromJson(decoded));
        } on Object catch (e) {
          // The file's JSON is not ours: whatever decoding or the model
          // rejects is one FormatException naming the line.
          throw FormatException(
            'Failed to parse NDJSON line: $trimmed',
            e,
          );
        }
      }
    }
    return resources;
  }

  /// Reads a file from [path] (which must be NDJSON) and decodes it into
  /// resources.
  ///
  /// Throws [FormatException] if the file contains invalid NDJSON.
  /// Throws an error if the file cannot be read, and [UnsupportedError] on
  /// platforms without file access (web, WASM) - load the content yourself
  /// and use [fromNdJson] there instead.
  Future<List<R>> fromFile(String path) async {
    final file = await readFileAsString(path);
    return fromNdJson(file);
  }

  /// Accepts data that is .zip / .tar.gz / .gz, etc., uncompresses it,
  /// and assumes the uncompressed data is NDJSON for decoding.
  Future<List<R>> fromCompressedData(
    String contentType,
    List<int> content,
  ) async {
    final resources = <R>[];

    if (contentType == 'application/zip' ||
        contentType == 'application/x-zip-compressed') {
      final archive = ZipDecoder().decodeBytes(content);
      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          resources.addAll(fromNdJson(utf8.decode(data)));
        }
      }
    } else if (contentType == 'application/x-tar') {
      // Typically means it's tar.gz
      final unzipped = const GZipDecoder().decodeBytes(content);
      final archive = TarDecoder().decodeBytes(unzipped);
      for (final file in archive) {
        if (file.isFile) {
          resources.addAll(fromNdJson(utf8.decode(file.content as List<int>)));
        }
      }
    } else if (contentType == 'application/gzip') {
      final data = const GZipDecoder().decodeBytes(content);
      resources.addAll(fromNdJson(utf8.decode(data)));
    }

    return resources;
  }

  /// Given a file that is presumably .zip / .tar.gz / .gz, uncompress and
  /// decode NDJSON.
  Future<List<R>> fromCompressedFile(String path) async {
    final data = await readFileAsBytes(path);
    final mimeType = lookupMimeType(path) ?? '';

    if (mimeType == 'application/zip' ||
        mimeType == 'application/x-zip-compressed' ||
        path.endsWith('.zip')) {
      return fromCompressedData('application/zip', data);
    } else if (mimeType == 'application/x-tar' || path.contains('.tar.gz')) {
      return fromCompressedData('application/x-tar', data);
    } else if (mimeType == 'application/gzip' || path.endsWith('.gz')) {
      return fromCompressedData('application/gzip', data);
    }

    return <R>[];
  }

  /// Converts a map of NDJSON Strings into a .zip file (as bytes).
  /// Keys = desired filename (without .ndjson)
  /// Values = NDJSON content
  static Future<List<int>?> toZipFile(Map<String, String> ndJsonStrings) async {
    final archive = Archive();
    ndJsonStrings.forEach((key, value) {
      final file = ArchiveFile('$key.ndjson', value.length, utf8.encode(value));
      archive.addFile(file);
    });
    return ZipEncoder().encode(archive);
  }

  /// Converts a map of NDJSON Strings into a single .gz file (as bytes).
  static List<int>? toGZipFile(Map<String, String> ndJsonStrings) {
    final combined = ndJsonStrings.values.join('\n');
    final bytes = utf8.encode(combined);
    return const GZipEncoder().encode(bytes);
  }

  /// Converts a map of NDJSON Strings into a .tar.gz file (as bytes).
  static Future<List<int>?> toTarGzFile(
    Map<String, String> ndJsonStrings,
  ) async {
    final archive = Archive();
    ndJsonStrings.forEach((key, value) {
      final file = ArchiveFile('$key.ndjson', value.length, utf8.encode(value));
      archive.addFile(file);
    });
    final tarred = TarEncoder().encode(archive);
    return const GZipEncoder().encode(tarred);
  }
}

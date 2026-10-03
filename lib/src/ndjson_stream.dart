import 'dart:convert';

import 'package:fhir_bulk/src/bulk_model.dart';
import 'package:fhir_bulk/src/fhir_bulk.dart';
import 'package:fhir_node/fhir_node.dart';

/// Newline-delimited JSON as streams: one resource a line, never a whole
/// file in memory.
///
/// [FhirBulk.toNdJson] and [FhirBulk.fromNdJson] take and return whole
/// lists, which is fine for a page of resources and not for an export: a
/// server writing 813k Observations as one list held 5.1 GB, streamed 741 MB
/// (fhirant REVIEW-2026-09-06 finding 34). A client reading a large file, a
/// server writing one, and a loader reading a bundled specification all go
/// through these. [lines] and [write] carry text and need no model;
/// [resources] and [encode] are [model]'s.
class NdjsonStream<R extends FhirNode> {
  /// Creates the resource streams over [model].
  const NdjsonStream(this.model);

  /// The version whose resources these are.
  final BulkModel<R> model;

  /// The non-blank lines of a UTF-8 byte stream: a file's `openRead()`, an
  /// HTTP body, an asset read in pieces. `\n` and `\r\n` both end a line, a
  /// line or a multi-byte character may be split across byte chunks, and
  /// blank lines are skipped, as [FhirBulk.fromNdJson] skips them.
  static Stream<String> lines(Stream<List<int>> bytes) => bytes
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.trim().isNotEmpty);

  /// The resources on [lines], one each. A line that is not JSON, not an
  /// object, or not a resource goes to [onBadLine] when given, else ends the
  /// stream with a [FormatException] naming the line, as [FhirBulk.fromNdJson]
  /// does.
  Stream<R> resources(
    Stream<String> lines, {
    void Function(String line, Object error)? onBadLine,
  }) async* {
    await for (final line in lines) {
      final R resource;
      try {
        resource = model.fromJson(
          jsonDecode(line.trim()) as Map<String, dynamic>,
        );
      } on Object catch (e) {
        // The file's JSON is not ours: whatever decoding or the model
        // rejects.
        if (onBadLine == null) {
          throw FormatException('Failed to parse NDJSON line: $line', e);
        }
        onBadLine(line, e);
        continue;
      }
      yield resource;
    }
  }

  /// [resources] as NDJSON lines, one each, without the line terminator.
  Stream<String> encode(Stream<R> resources) =>
      resources.map((r) => jsonEncode(model.toJson(r)));

  /// Writes [lines] to [sink], one per line with `\n`, as they arrive, and
  /// returns how many were written. When [flush] is given (an `IOSink`'s
  /// `flush`) it is awaited every [flushEvery] lines and once at the end, so
  /// the file rather than the heap holds the output; a sink without one
  /// buffers as it buffers.
  static Future<int> write(
    Stream<String> lines,
    StringSink sink, {
    Future<void> Function()? flush,
    int flushEvery = 500,
  }) async {
    var count = 0;
    await for (final line in lines) {
      sink.writeln(line);
      count++;
      if (flush != null && count % flushEvery == 0) await flush();
    }
    if (flush != null) await flush();
    return count;
  }
}

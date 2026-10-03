import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fhir_bulk/fhir_bulk.dart';
import 'package:test/test.dart';

import 'support/json_node.dart';

/// NDJSON as streams: lines from bytes however the bytes are chunked,
/// resources from lines, lines to a sink with periodic flushes.
void main() {
  String patient(String id) => '{"resourceType":"Patient","id":"$id"}';
  const stream = NdjsonStream(testModel);
  const bulk = FhirBulk(testModel);

  group('NdjsonStream.lines', () {
    test(r'splits on \n and \r\n, skips blank lines', () async {
      final text = '${patient('a')}\r\n\n${patient('b')}\n   \n${patient('c')}';
      final lines =
          await NdjsonStream.lines(Stream.value(utf8.encode(text))).toList();
      expect(lines, [patient('a'), patient('b'), patient('c')]);
    });

    test(
      'a line and a multi-byte character split across byte chunks',
      () async {
        // "Bénédicte": the é is two bytes; cut the stream inside it and inside
        // the second line.
        final text =
            '{"resourceType":"Patient","id":"x","name":[{"family":'
            '"Bénédicte"}]}\n${patient('y')}\n';
        final bytes = utf8.encode(text);
        final cut1 =
            utf8
                .encode(
                  '{"resourceType":"Patient","id":"x","name":'
                  '[{"family":"B',
                )
                .length +
            1; // one byte into é
        final cut2 = bytes.length - 8;
        final chunks = [
          bytes.sublist(0, cut1),
          bytes.sublist(cut1, cut2),
          bytes.sublist(cut2),
        ];
        final lines =
            await NdjsonStream.lines(Stream.fromIterable(chunks)).toList();
        expect(lines, hasLength(2));
        expect(lines.first, contains('Bénédicte'));
        expect(lines.last, patient('y'));
      },
    );

    test('reads the Account fixture file as the list helper does', () async {
      const path = 'test/ndjson/Account.ndjson';
      final streamed =
          await stream
              .resources(NdjsonStream.lines(File(path).openRead()))
              .toList();
      final listed = await bulk.fromFile(path);
      expect(streamed.map(testModel.toJson), listed.map(testModel.toJson));
      expect(streamed, isNotEmpty);
    });
  });

  group('NdjsonStream.resources', () {
    test(
      'parses each line; a bad line ends the stream with FormatException',
      () async {
        final resources = stream.resources(
          Stream.fromIterable([patient('a'), 'not json', patient('b')]),
        );
        final seen = <String>[];
        await expectLater(
          () => resources.forEach((r) => seen.add(idOf(r)!)),
          throwsA(isA<FormatException>()),
        );
        expect(seen, ['a']);
      },
    );

    test(
      'with onBadLine the bad lines are reported and the rest parsed',
      () async {
        final bad = <String>[];
        final ids =
            await stream
                .resources(
                  Stream.fromIterable([
                    patient('a'),
                    'not json',
                    '{"id":"no type"}',
                    '{"resourceType":"NotAResource","id":"z"}',
                    patient('b'),
                  ]),
                  onBadLine: (line, _) => bad.add(line),
                )
                .map((r) => idOf(r)!)
                .toList();
        expect(ids, ['a', 'b']);
        expect(bad, hasLength(3));
      },
    );

    test('encode gives one line per resource, round-tripping', () async {
      final lines =
          await stream
              .encode(
                Stream.fromIterable([
                  resource('Patient', 'p'),
                  resource('Observation', 'o', {
                    'status': 'final',
                    'code': {'text': 'x'},
                  }),
                ]),
              )
              .toList();
      expect(lines, hasLength(2));
      expect(lines.every((l) => !l.contains('\n')), isTrue);
      final back =
          await stream
              .resources(Stream.fromIterable(lines))
              .map((r) => r.fhirType)
              .toList();
      expect(back, ['Patient', 'Observation']);
    });
  });

  group('NdjsonStream.write', () {
    test('writes each line with a newline, counts, flushes every N and at '
        'the end', () async {
      final sink = StringBuffer();
      var flushes = 0;
      final count = await NdjsonStream.write(
        Stream.fromIterable([for (var i = 0; i < 1201; i++) patient('$i')]),
        sink,
        flush: () async => flushes++,
      );
      expect(count, 1201);
      expect(flushes, 3); // 500, 1000, end
      final text = sink.toString();
      expect(text.endsWith('\n'), isTrue);
      expect(const LineSplitter().convert(text), hasLength(1201));
    });

    test('to a real file through IOSink.flush', () async {
      final dir = await Directory.systemTemp.createTemp('ndjson_stream_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/out.ndjson');
      final sink = file.openWrite();
      try {
        final count = await NdjsonStream.write(
          Stream.fromIterable([patient('a'), patient('b')]),
          sink,
          flush: sink.flush,
        );
        expect(count, 2);
      } finally {
        await sink.close();
      }
      expect(await file.readAsString(), '${patient('a')}\n${patient('b')}\n');
    });
  });
}

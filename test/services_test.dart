import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakagain/core/answer_matcher.dart';
import 'package:speakagain/models/pack.dart';
import 'package:speakagain/models/settings.dart';
import 'package:speakagain/services/models/model_catalog.dart';
import 'package:speakagain/services/pack_importer.dart';
import 'package:speakagain/services/speech/recorder.dart';
import 'package:speakagain/services/speech/wav.dart';

Float32List tone(double seconds, double amplitude, {int rate = 16000}) => Float32List.fromList([
  for (var i = 0; i < (rate * seconds).round(); i++) amplitude * math.sin(2 * math.pi * 220 * i / rate),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speech endpointer', () {
    test('finds speech between silences and trims around it', () {
      final e = SpeechEndpointer();
      var done = e.add(tone(1.0, 0.001));
      expect(done, isFalse);
      done = e.add(tone(0.8, 0.3));
      expect(done, isFalse);
      expect(e.heardSpeech, isTrue);
      done = e.add(tone(1.6, 0.001));
      expect(done, isTrue);
      final recording = e.finish();
      expect(recording.heardSpeech, isTrue);
      // 0.8 s of speech plus a little room on each side.
      expect(recording.duration.inMilliseconds, inInclusiveRange(1300, 1600));
    });

    test('waits through short pauses inside an answer', () {
      final e = SpeechEndpointer();
      e.add(tone(0.5, 0.3));
      expect(e.add(tone(0.9, 0.001)), isFalse);
      expect(e.add(tone(0.5, 0.3)), isFalse);
    });

    test('gives up when nothing is said', () {
      final e = SpeechEndpointer(maxWait: const Duration(seconds: 2));
      expect(e.add(tone(2.1, 0.002)), isTrue);
      expect(e.finish().heardSpeech, isFalse);
    });

    test('stops at the maximum length', () {
      final e = SpeechEndpointer(maxLength: const Duration(seconds: 3));
      expect(e.add(tone(3.1, 0.3)), isTrue);
    });
  });

  test('WAV encoding has a valid header', () {
    final wav = encodeWav(Float32List.fromList([0, 0.5, -0.5, 1]), 16000);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
    expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
    expect(wav.length, 44 + 8);
  });

  test('quiet recordings are made louder for playback', () {
    final quiet = Float32List.fromList([0.05, -0.1]);
    expect(normalizeLoudness(quiet).reduce(math.max), closeTo(0.35, 1e-6));
  });

  group('settings', () {
    test('round-trip and ignore unknown values', () {
      const s = AppSettings(
        language: 'fr',
        sessionLength: 15,
        strictness: Strictness.close,
        theme: ThemeChoice.contrast,
      );
      expect(AppSettings.fromJson(s.toJson()).toJson(), s.toJson());
      final odd = AppSettings.fromJson({'sessionLength': 7, 'theme': 'neon', 'pictureChoices': 9});
      expect(odd.sessionLength, 10);
      expect(odd.theme, ThemeChoice.system);
      expect(odd.pictureChoices, 3);
    });
  });

  group('pack importer', () {
    final packJson = {
      'format': 1,
      'id': 'en-kitchen',
      'version': '1.0.0',
      'language': 'en',
      'title': 'Kitchen',
      'exercises': ['name', 'listen'],
      'items': [
        {'id': 'pan', 'answer': 'pan', 'image': 'images/pan.png'},
        {'id': 'cup', 'answer': 'cup', 'image': 'openmoji:2615'},
      ],
    };

    Uint8List zip(Map<String, List<int>> files) {
      final archive = Archive();
      for (final e in files.entries) {
        archive.addFile(ArchiveFile.bytes(e.key, e.value));
      }
      return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    }

    test('reads a zip with pictures, at the root or in a folder', () {
      for (final prefix in ['', 'kitchen/']) {
        final imported = const PackImporter().read(
          zip({
            '${prefix}pack.json': utf8.encode(jsonEncode(packJson)),
            '${prefix}images/pan.png': [1, 2, 3],
          }),
        );
        expect(imported.pack.id, 'en-kitchen');
        expect(imported.pack.source, PackSource.imported);
        expect(imported.images['images/pan.png'], [1, 2, 3]);
      }
    });

    test('explains a missing picture', () {
      expect(
        () => const PackImporter().read(zip({'pack.json': utf8.encode(jsonEncode(packJson))})),
        throwsA(isA<PackFormatException>().having((e) => e.problems.join(), 'problems', contains('images/pan.png'))),
      );
    });

    test('reads a bare pack.json that only uses symbols', () {
      final json = {
        ...packJson,
        'items': [
          {'id': 'cup', 'answer': 'cup', 'image': 'openmoji:2615'},
          {'id': 'tea', 'answer': 'tea', 'image': 'openmoji:1F375'},
        ],
      };
      expect(const PackImporter().read(Uint8List.fromList(utf8.encode(jsonEncode(json)))).pack.items, hasLength(2));
    });

    test('rejects something that is not a pack', () {
      expect(
        () => const PackImporter().read(Uint8List.fromList(utf8.encode('hello'))),
        throwsA(isA<PackFormatException>()),
      );
    });
  });

  test('model catalog lists both speech models and a voice for most languages', () async {
    final catalog = await ModelCatalog.load(rootBundle);
    expect(catalog.recognizers.map((r) => r.size), containsAll(RecognizerSize.values));
    expect(catalog.voiceData, isNotNull);
    for (final language in ['en', 'es', 'fr', 'de', 'pt', 'nl', 'pl']) {
      expect(catalog.voicesFor(language), isNotEmpty, reason: language);
    }
    for (final item in [...catalog.recognizers, ...catalog.voices, catalog.voiceData!]) {
      for (final file in item.files) {
        expect(file.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(
          catalog.urlFor(file).toString(),
          startsWith('https://github.com/lobojoel2003/Speakagain/releases/download/models-v1/'),
        );
      }
    }
    expect(
      catalog.recognizer(RecognizerSize.small).totalBytes,
      lessThan(catalog.recognizer(RecognizerSize.standard).totalBytes),
    );
  });
}

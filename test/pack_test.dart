import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakagain/core/languages.dart';
import 'package:speakagain/models/pack.dart';

Map<String, Object?> minimal() => {
  'format': 1,
  'id': 'en-test',
  'version': '1.0.0',
  'language': 'en',
  'title': 'Test',
  'exercises': ['name', 'listen', 'read', 'repeat', 'complete'],
  'categories': {'food': 'Something to eat'},
  'items': [
    {'id': 'apple', 'answer': 'apple', 'image': 'openmoji:1F34E', 'category': 'food', 'sentence': 'An ___ a day.'},
    {'id': 'pear', 'answer': 'pear', 'image': 'images/pear.png'},
  ],
};

void main() {
  group('Pack.fromJson', () {
    test('reads a valid pack', () {
      final pack = Pack.fromJson(minimal());
      expect(pack.id, 'en-test');
      expect(pack.items, hasLength(2));
      expect(pack.offers(ExerciseType.complete), isTrue);
      expect(pack.itemsFor(ExerciseType.complete).map((i) => i.id), ['apple']);
      expect(pack.cueFor(pack.items.first), 'Something to eat');
      expect(pack.localImages, {'images/pear.png'});
      expect(pack.openMojiCodes, {'1F34E'});
    });

    test('round-trips through JSON', () {
      final pack = Pack.fromJson(minimal());
      final again = Pack.fromJson(jsonDecode(jsonEncode(pack.toJson())));
      expect(again.toJson(), pack.toJson());
    });

    test('lists every problem at once', () {
      final json = minimal()
        ..['id'] = 'Bad Id'
        ..['format'] = 2
        ..['exercises'] = ['name', 'sing'];
      (json['items'] as List).add({'id': 'apple', 'answer': '', 'image': '../secret.png', 'sentence': 'no blank'});
      try {
        Pack.fromJson(json);
        fail('should throw');
      } on PackFormatException catch (e) {
        final all = e.problems.join('\n');
        expect(all, contains('"format"'));
        expect(all, contains('"id"'));
        expect(all, contains('unknown exercise "sing"'));
        expect(all, contains('duplicate id "apple"'));
        expect(all, contains('"answer"'));
        expect(all, contains('"image"'));
        expect(all, contains('"sentence"'));
      }
    });

    test('rejects image paths that leave the pack', () {
      for (final bad in ['images/../x.png', '/etc/x.png', 'images/x.exe', 'http://x/y.png']) {
        final json = minimal();
        (json['items'] as List<Object?>)[1] = {'id': 'pear', 'answer': 'pear', 'image': bad};
        expect(() => Pack.fromJson(json), throwsA(isA<PackFormatException>()), reason: bad);
      }
    });

    test('needs pictures for naming and two for listening', () {
      final json = minimal()
        ..['items'] = [
          {'id': 'a', 'answer': 'a', 'image': 'openmoji:1F34E'},
        ];
      expect(() => Pack.fromJson(json), throwsA(isA<PackFormatException>()));
    });
  });

  group('starter packs', () {
    final files = Directory('assets/packs')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('pack.json'))
        .toList();

    test('every language has the four starter packs', () {
      for (final language in appLanguages) {
        for (final slug in ['everyday-words', 'finish-the-sentence', 'counting-and-days', 'useful-phrases']) {
          expect(
            File('assets/packs/${language.code}/${language.code}-$slug/pack.json').existsSync(),
            isTrue,
            reason: '${language.code}-$slug',
          );
        }
      }
    });

    for (final file in files) {
      test('${file.path} is valid', () {
        final pack = Pack.fromJson(jsonDecode(file.readAsStringSync()));
        final folder = file.parent;
        expect(
          folder.uri.pathSegments.where((s) => s.isNotEmpty).last,
          pack.id,
          reason: 'folder name must be the pack id',
        );
        expect(
          folder.parent.uri.pathSegments.where((s) => s.isNotEmpty).last,
          pack.language,
          reason: 'pack is in its language folder',
        );
        expect(pack.id.startsWith('${pack.language}-'), isTrue, reason: 'id starts with the language code');
        for (final code in pack.openMojiCodes) {
          expect(File('assets/symbols/openmoji/$code.svg').existsSync(), isTrue, reason: 'symbol $code is bundled');
        }
        for (final image in pack.localImages) {
          expect(File('${folder.path}/$image').existsSync(), isTrue, reason: image);
        }
        for (final item in pack.items) {
          expect(item.answers.toSet(), hasLength(item.answers.length), reason: '${item.id} lists an answer twice');
        }
      });
    }

    test('everyday words are the same concepts in every language', () {
      Set<String> ids(String code) =>
          Pack.fromJson(jsonDecode(File('assets/packs/$code/$code-everyday-words/pack.json').readAsStringSync())).items
              .map((i) => i.id)
              .toSet();
      final english = ids('en');
      for (final language in appLanguages) {
        expect(ids(language.code), english, reason: language.code);
      }
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakagain/core/languages.dart';

final _placeholder = RegExp(r'\{(\w+)[,}]');

void main() {
  final english = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, Object?>;
  final keys = english.keys.where((k) => !k.startsWith('@')).toSet();

  for (final language in appLanguages) {
    test('${language.nativeName} has every string with the same placeholders', () {
      final file = File('lib/l10n/app_${language.code}.arb');
      expect(file.existsSync(), isTrue);
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      expect(arb['@@locale'], language.code);
      final theirs = arb.keys.where((k) => !k.startsWith('@')).toSet();
      expect(theirs.difference(keys), isEmpty, reason: 'unknown keys');
      expect(keys.difference(theirs), isEmpty, reason: 'missing keys');
      for (final key in keys) {
        final ours = _placeholder.allMatches(english[key]! as String).map((m) => m.group(1)).toSet();
        final translated = _placeholder.allMatches(arb[key]! as String).map((m) => m.group(1)).toSet();
        expect(translated, ours, reason: '$key placeholders');
        expect((arb[key]! as String).trim(), isNotEmpty, reason: key);
      }
      expect(arb['appTitle'], 'Speakagain', reason: 'the app name is not translated');
    });
  }
}

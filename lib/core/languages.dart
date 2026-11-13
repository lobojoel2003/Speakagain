import 'package:flutter/widgets.dart';

/// A language Speakagain can be used in: its app text, starter packs, voice
/// and speech checking all follow this choice.
@immutable
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.ttsLocale,
    this.wordsHaveSpaces = true,
  });

  /// ISO 639-1 code, used for packs (`assets/packs/<code>/`), app text and
  /// Whisper's language setting.
  final String code;

  /// The language's name written in the language itself, so people can find
  /// their own language without reading English.
  final String nativeName;
  final String englishName;

  /// Locale passed to the phone's text-to-speech engine.
  final String ttsLocale;

  /// False for languages written without spaces between words (Chinese), so
  /// answer checking compares characters instead of words.
  final bool wordsHaveSpaces;

  Locale get locale => Locale(code);

  bool get isRtl => code == 'ar';
}

/// Every language with app text and starter packs. Keep in step with
/// `lib/l10n/app_<code>.arb` and `assets/packs/<code>/`.
const List<AppLanguage> appLanguages = [
  AppLanguage(code: 'en', nativeName: 'English', englishName: 'English', ttsLocale: 'en-US'),
  AppLanguage(code: 'es', nativeName: 'Español', englishName: 'Spanish', ttsLocale: 'es-ES'),
  AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French', ttsLocale: 'fr-FR'),
  AppLanguage(code: 'de', nativeName: 'Deutsch', englishName: 'German', ttsLocale: 'de-DE'),
  AppLanguage(code: 'it', nativeName: 'Italiano', englishName: 'Italian', ttsLocale: 'it-IT'),
  AppLanguage(code: 'pt', nativeName: 'Português', englishName: 'Portuguese', ttsLocale: 'pt-BR'),
  AppLanguage(code: 'nl', nativeName: 'Nederlands', englishName: 'Dutch', ttsLocale: 'nl-NL'),
  AppLanguage(code: 'pl', nativeName: 'Polski', englishName: 'Polish', ttsLocale: 'pl-PL'),
  AppLanguage(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi', ttsLocale: 'hi-IN'),
  AppLanguage(code: 'ar', nativeName: 'العربية', englishName: 'Arabic', ttsLocale: 'ar-SA'),
  AppLanguage(
    code: 'zh',
    nativeName: '中文',
    englishName: 'Chinese (Mandarin)',
    ttsLocale: 'zh-CN',
    wordsHaveSpaces: false,
  ),
];

AppLanguage languageFor(String? code) {
  for (final language in appLanguages) {
    if (language.code == code) return language;
  }
  return appLanguages.first;
}

bool isSupportedLanguage(String code) => appLanguages.any((l) => l.code == code);

/// The best starting language for a device locale, or English.
AppLanguage languageForLocale(Locale? locale) {
  if (locale == null) return appLanguages.first;
  return languageFor(isSupportedLanguage(locale.languageCode) ? locale.languageCode : 'en');
}

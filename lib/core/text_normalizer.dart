import 'languages.dart';

/// Turns recogniser output and pack answers into a plain form for comparison:
/// lower case, no punctuation, no accents, single spaces, and per-language
/// spelling variants folded together.
class TextNormalizer {
  TextNormalizer(String language)
      : language = language.split('-').first.toLowerCase(),
        wordsHaveSpaces = !isSupportedLanguage(language.split('-').first.toLowerCase()) ||
            languageFor(language.split('-').first.toLowerCase()).wordsHaveSpaces;

  /// Base language code, such as `pt` for `pt-BR`.
  final String language;
  final bool wordsHaveSpaces;

  static final RegExp _separators = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
  static final RegExp _arabicMarks = RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');

  String normalize(String input) {
    var text = input.toLowerCase();
    switch (language) {
      case 'ar':
        text = text
            .replaceAll(_arabicMarks, '')
            .replaceAll(RegExp('[\u0622\u0623\u0625\u0671]'), '\u0627') // alef forms -> ا
            .replaceAll('\u0629', '\u0647') // ة -> ه
            .replaceAll('\u0649', '\u064A'); // ى -> ي
        text = _mapRunes(text, _arabicDigits);
      case 'hi':
        text = text
            .replaceAll('\u093C', '') // nukta
            .replaceAll('\u0901', '\u0902'); // chandrabindu -> anusvara
        text = _mapRunes(text, _devanagariDigits);
      case 'zh':
        text = _mapRunes(text, _traditionalToSimplified);
      default:
        text = _mapRunes(text, _latinFold);
    }
    return text.replaceAll(_separators, ' ').trim();
  }

  static String _mapRunes(String text, Map<int, String> map) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      out.write(map[rune] ?? String.fromCharCode(rune));
    }
    return out.toString();
  }
}

final Map<int, String> _latinFold = _buildFold({
  'a': 'àáâãäåāăą',
  'c': 'çćĉċč',
  'd': 'ďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉ',
  'o': 'òóôõöøōŏő',
  'r': 'ŕŗř',
  's': 'śŝşšș',
  't': 'ţťŧț',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
  'ss': 'ß',
  'ae': 'æ',
  'oe': 'œ',
  "'": '’‘ʼ',
});

Map<int, String> _buildFold(Map<String, String> groups) => {
      for (final entry in groups.entries)
        for (final rune in entry.value.runes) rune: entry.key,
    };

final Map<int, String> _arabicDigits = {
  for (var i = 0; i < 10; i++) 0x0660 + i: '$i',
  for (var i = 0; i < 10; i++) 0x06F0 + i: '$i',
};

final Map<int, String> _devanagariDigits = {
  for (var i = 0; i < 10; i++) 0x0966 + i: '$i',
};

/// Traditional characters a recogniser may write for words in the Chinese packs.
final Map<int, String> _traditionalToSimplified = {
  for (final pair in const [
    '蘋苹', '蔔卜', '蘿萝', '麵面', '雞鸡', '書书', '門门', '鑰钥', '鐘钟', '錶表', '電电', '話话',
    '鏡镜', '傘伞', '襪袜', '襯衬', '魚鱼', '鳥鸟', '馬马', '車车', '飛飞', '機机', '腳脚', '頭头',
    '個个', '謝谢', '們们', '時时', '間间', '幫帮', '餓饿', '愛爱', '見见', '嗎吗', '廁厕', '請请',
    '樹树', '陽阳', '貓猫', '對对', '說说', '聽听', '這这', '還还', '點点', '鬧闹', '號号', '覺觉',
    '舊旧', '學学', '開开', '關关', '燈灯', '牆墙', '窗窗', '過过', '週周', '來来', '兒儿', '氣气',
    '漢汉', '語语', '藥药', '醫医', '湯汤', '蘭兰', '萬万', '兩两', '雙双', '條条', '張张', '輛辆',
  ])
    pair.runes.first: String.fromCharCode(pair.runes.last),
};

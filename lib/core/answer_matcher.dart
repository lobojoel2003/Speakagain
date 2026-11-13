import 'dart:math' as math;

import 'text_normalizer.dart';

/// How a spoken answer compares with what was expected.
enum MatchLevel {
  /// The answer was said (or close enough to count).
  said,

  /// Part of the answer was heard: encourage and try again.
  nearly,

  /// The recogniser heard something else, or nothing.
  notYet,
}

/// How closely spoken answers are checked. People early in recovery, and
/// recognisers in languages they handle less well, need a gentler check.
enum Strictness {
  gentle(said: 0.72, nearly: 0.4),
  close(said: 0.86, nearly: 0.55);

  const Strictness({required this.said, required this.nearly});

  final double said;
  final double nearly;
}

class AnswerCheck {
  const AnswerCheck(this.level, this.score, this.heard, {this.matched});

  final MatchLevel level;

  /// 0..1, how similar the best-matching part of [heard] was to an answer.
  final double score;

  /// What the recogniser heard, as it wrote it.
  final String heard;

  /// The accepted answer that matched best.
  final String? matched;

  @override
  String toString() => 'AnswerCheck($level, ${score.toStringAsFixed(2)}, "$heard" ~ "$matched")';
}

/// Compares what a speech recogniser heard with the accepted answers.
///
/// Recognisers struggle with single words, and speech after a stroke is often
/// slower or less clear, so the comparison is deliberately forgiving: it finds
/// the answer anywhere in what was heard ("an apple", "apple apple"), ignores
/// case, punctuation, accents and doubled letters, and allows small differences.
class AnswerMatcher {
  const AnswerMatcher({this.strictness = Strictness.gentle});

  final Strictness strictness;

  AnswerCheck check({required String heard, required List<String> answers, required String language}) {
    final normalizer = TextNormalizer(language);
    final heardText = normalizer.normalize(heard);
    if (heardText.isEmpty || answers.isEmpty) return AnswerCheck(MatchLevel.notYet, 0, heard);

    var best = 0.0;
    String? bestAnswer;
    for (final answer in answers) {
      final target = normalizer.normalize(answer);
      if (target.isEmpty) continue;
      final score = _score(heardText, target, normalizer.wordsHaveSpaces);
      if (score > best) {
        best = score;
        bestAnswer = answer;
      }
      if (best >= 1) break;
    }

    final level = best >= strictness.said
        ? MatchLevel.said
        : best >= strictness.nearly
        ? MatchLevel.nearly
        : MatchLevel.notYet;
    return AnswerCheck(level, best, heard, matched: bestAnswer);
  }

  double _score(String heard, String target, bool wordsHaveSpaces) {
    final heardKey = soundKey(heard);
    final targetKey = soundKey(target);
    if (heardKey == targetKey) return 1;

    if (!wordsHaveSpaces) {
      final h = heardKey.replaceAll(' ', '');
      final t = targetKey.replaceAll(' ', '');
      if (h.contains(t)) return 1;
      return _bestWindow(h.split(''), t, joiner: '');
    }

    final heardWords = heardKey.split(' ');
    final targetWords = targetKey.split(' ');
    // The answer said as part of a longer phrase ("it's an apple").
    for (var i = 0; i + targetWords.length <= heardWords.length; i++) {
      var all = true;
      for (var j = 0; j < targetWords.length; j++) {
        if (heardWords[i + j] != targetWords[j]) {
          all = false;
          break;
        }
      }
      if (all) return 1;
    }
    // Compare without word breaks too: recognisers split and join words ("man sana").
    final joinedTarget = targetWords.join();
    return math.max(_bestWindow(heardWords, joinedTarget, joiner: ''), similarity(heardWords.join(), joinedTarget));
  }

  /// Best similarity between [target] and any run of neighbouring [parts].
  double _bestWindow(List<String> parts, String target, {required String joiner}) {
    var best = 0.0;
    final maxRun = math.min(parts.length, (target.length * 2).clamp(1, 64));
    for (var start = 0; start < parts.length; start++) {
      final buffer = StringBuffer();
      for (var end = start; end < parts.length && end - start < maxRun; end++) {
        if (end > start) buffer.write(joiner);
        buffer.write(parts[end]);
        final candidate = buffer.toString();
        if (candidate.length > target.length * 2 + 2) break;
        best = math.max(best, similarity(candidate, target));
        if (best >= 1) return 1;
      }
    }
    return best;
  }
}

/// A rough spoken form: doubled letters collapsed, so "perro" ~ "pero" and
/// "Pannaana" ~ "panana". Spaces are kept.
String soundKey(String text) {
  final out = StringBuffer();
  int? last;
  for (final rune in text.runes) {
    if (rune == last && rune != 0x20) continue;
    out.writeCharCode(rune);
    last = rune;
  }
  return out.toString();
}

/// 1 minus the Levenshtein distance divided by the longer length (0..1),
/// comparing Unicode code points.
double similarity(String a, String b) {
  if (a == b) return 1;
  final x = a.runes.toList();
  final y = b.runes.toList();
  if (x.isEmpty || y.isEmpty) return 0;
  var previous = List<int>.generate(y.length + 1, (i) => i);
  var current = List<int>.filled(y.length + 1, 0);
  for (var i = 1; i <= x.length; i++) {
    current[0] = i;
    for (var j = 1; j <= y.length; j++) {
      final cost = x[i - 1] == y[j - 1] ? 0 : 1;
      current[j] = math.min(math.min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return 1 - previous[y.length] / math.max(x.length, y.length);
}

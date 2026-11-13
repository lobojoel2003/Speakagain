import 'package:flutter_test/flutter_test.dart';
import 'package:speakagain/core/answer_matcher.dart';
import 'package:speakagain/core/text_normalizer.dart';

void main() {
  const matcher = AnswerMatcher();
  MatchLevel level(String heard, List<String> answers, [String language = 'en']) =>
      matcher.check(heard: heard, answers: answers, language: language).level;

  group('normalizing', () {
    test('ignores case, punctuation and accents', () {
      expect(TextNormalizer('es').normalize('¡Miércoles!'), 'miercoles');
      expect(TextNormalizer('fr').normalize("L'œuf."), 'l oeuf');
      expect(TextNormalizer('de').normalize('Fuß'), 'fuss');
      expect(TextNormalizer('pl').normalize('Łóżko'), 'lozko');
    });

    test('folds Arabic letter forms, marks and the article', () {
      expect(TextNormalizer('ar').normalize('الكِتَاب'), TextNormalizer('ar').normalize('كتاب'));
      expect(TextNormalizer('ar').normalize('أنف'), TextNormalizer('ar').normalize('انف'));
      expect(TextNormalizer('ar').normalize('٣'), '3');
    });

    test('folds Hindi spelling variants', () {
      expect(TextNormalizer('hi').normalize('दरवाज़ा'), TextNormalizer('hi').normalize('दरवाजा'));
      expect(TextNormalizer('hi').normalize('आँख'), TextNormalizer('hi').normalize('आंख'));
    });

    test('maps traditional Chinese characters used in the packs', () {
      expect(TextNormalizer('zh').normalize('蘋果。'), '苹果');
      expect(TextNormalizer('zh').normalize('飛機'), '飞机');
    });

    test('uses the base language of a regional code', () {
      expect(TextNormalizer('pt-BR').language, 'pt');
      expect(TextNormalizer('zh-CN').wordsHaveSpaces, isFalse);
    });
  });

  group('matching', () {
    test('accepts the answer however the recogniser writes it', () {
      expect(level('Apple.', ['apple']), MatchLevel.said);
      expect(level('Apple. Apple. Apple.', ['apple']), MatchLevel.said);
      expect(level("It's an apple", ['apple']), MatchLevel.said);
      expect(level('THANK YOU!', ['thank you']), MatchLevel.said);
    });

    test('accepts any listed alternative', () {
      expect(level('bike', ['bicycle', 'bike']), MatchLevel.said);
      expect(level('7', ['siete', '7'], 'es'), MatchLevel.said);
    });

    test('forgives doubled letters, split words and small slips', () {
      expect(level('pero', ['perro'], 'es'), MatchLevel.said);
      expect(level('Man sana', ['manzana'], 'es'), MatchLevel.said);
      expect(level('Mircoles', ['miércoles'], 'es'), MatchLevel.said);
      expect(level('Panaana.', ['banana']), MatchLevel.said);
    });

    test('says "nearly" for part of the word', () {
      expect(level('Bad', ['bed']), MatchLevel.nearly);
      expect(level('chai', ['chair']), MatchLevel.said);
      expect(level('car', ['carrot']), MatchLevel.nearly);
    });

    test('does not accept something else', () {
      expect(level('dog', ['apple']), MatchLevel.notYet);
      expect(level('', ['apple']), MatchLevel.notYet);
      expect(level('...', ['apple']), MatchLevel.notYet);
    });

    test('closely is stricter than gently', () {
      const close = AnswerMatcher(strictness: Strictness.close);
      expect(matcher.check(heard: 'Mircoles', answers: ['miércoles'], language: 'es').level, MatchLevel.said);
      expect(close.check(heard: 'Miergores', answers: ['miércoles'], language: 'es').level, isNot(MatchLevel.said));
    });

    test('works for languages without spaces', () {
      expect(level('这是苹果。', ['苹果'], 'zh'), MatchLevel.said);
      expect(level('苹', ['苹果'], 'zh'), MatchLevel.nearly);
      expect(level('香蕉', ['苹果'], 'zh'), MatchLevel.notYet);
    });

    test('works in Arabic and Hindi', () {
      expect(level('التفاحة', ['تفاحة'], 'ar'), MatchLevel.said);
      expect(level('मुझे सेब चाहिए', ['सेब'], 'hi'), MatchLevel.said);
    });

    test('reports what matched', () {
      final check = matcher.check(heard: 'a bike', answers: ['bicycle', 'bike'], language: 'en');
      expect(check.matched, 'bike');
      expect(check.score, 1);
    });
  });

  test('similarity', () {
    expect(similarity('abc', 'abc'), 1);
    expect(similarity('abc', ''), 0);
    expect(similarity('kitten', 'sitting'), closeTo(1 - 3 / 7, 1e-9));
  });
}

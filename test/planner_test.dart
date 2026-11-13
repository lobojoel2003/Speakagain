import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:speakagain/core/session_planner.dart';
import 'package:speakagain/models/pack.dart';
import 'package:speakagain/models/progress.dart';

Pack pack() => Pack.fromJson({
  'format': 1,
  'id': 'en-p',
  'version': '1.0.0',
  'language': 'en',
  'title': 'P',
  'exercises': ['name', 'listen', 'read', 'repeat', 'complete'],
  'categories': {'f': 'food', 'a': 'animal'},
  'items': [
    for (final (i, word) in ['apple', 'bread', 'cheese', 'dog', 'cat', 'egg'].indexed)
      {
        'id': word,
        'answer': word,
        'image': 'openmoji:1F34$i',
        'category': i < 3 || i == 5 ? 'f' : 'a',
        if (i.isEven) 'sentence': 'A ___.',
      },
  ],
});

void main() {
  final now = DateTime(2026, 11, 13, 10);
  const planner = SessionPlanner();

  test('due items come first, then new, then the rest', () {
    final progress = {
      'en-p/apple': ItemProgress(attempts: 2, box: 2, due: now.add(const Duration(days: 3)), lastSeen: now),
      'en-p/bread': ItemProgress(attempts: 1, box: 1, due: now.subtract(const Duration(days: 1)), lastSeen: now),
    };
    final tasks = planner.plan(packs: [pack()], progress: progress, count: 6, now: now);
    expect(tasks.map((t) => t.item.id).toList(), ['bread', 'cheese', 'dog', 'cat', 'egg', 'apple']);
  });

  test('limits the session length', () {
    expect(planner.plan(packs: [pack()], progress: {}, count: 3, now: now), hasLength(3));
  });

  test('one exercise only uses items that support it', () {
    final tasks = planner.plan(packs: [pack()], progress: {}, count: 10, now: now, only: ExerciseType.complete);
    expect(tasks.map((t) => t.item.id), ['apple', 'cheese', 'cat']);
    expect(tasks.every((t) => t.type == ExerciseType.complete), isTrue);
  });

  test('mixed practice moves from easier to harder exercises', () {
    final p = pack();
    final apple = p.item('apple')!;
    expect(SessionPlanner.exerciseFor(p, apple, const ItemProgress()), ExerciseType.repeat);
    expect(SessionPlanner.exerciseFor(p, apple, const ItemProgress(box: 1)), ExerciseType.listen);
    expect(SessionPlanner.exerciseFor(p, apple, const ItemProgress(box: 2)), ExerciseType.read);
    expect(SessionPlanner.exerciseFor(p, apple, const ItemProgress(box: 4)), ExerciseType.name);
  });

  test('picture choices include the answer and different pictures', () {
    final p = pack();
    final answer = p.item('dog')!;
    for (var seed = 0; seed < 20; seed++) {
      final choices = SessionPlanner.choicesFor(p, answer, 3, math.Random(seed));
      expect(choices, hasLength(3));
      expect(choices, contains(answer));
      expect(choices.map((c) => c.image).toSet(), hasLength(3));
      // Easier start: the others come from another category when possible.
      expect(choices.where((c) => c != answer).every((c) => c.category == 'f'), isTrue);
    }
  });

  group('progress', () {
    test('moves up when said alone, down when the word was needed', () {
      var p = const ItemProgress();
      p = p.record(Outcome.independent, now);
      expect(p.box, 1);
      expect(p.due, DateTime(2026, 11, 14));
      p = p.record(Outcome.independent, now).record(Outcome.independent, now);
      expect(p.box, 3);
      expect(p.isEasier, isTrue);
      p = p.record(Outcome.withHint, now);
      expect(p.box, 3);
      p = p.record(Outcome.withModel, now);
      expect(p.box, 2);
      expect(p.attempts, 5);
      expect(p.independent, 3);
      expect(p.helped, 2);
    });

    test('survives JSON', () {
      final p = const ItemProgress().record(Outcome.independent, now);
      final again = ItemProgress.fromJson(p.toJson());
      expect(again.toJson(), p.toJson());
    });

    test('day key', () => expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05'));
  });
}

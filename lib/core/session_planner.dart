import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/pack.dart';
import '../models/progress.dart';

/// One turn in a practice session.
@immutable
class PracticeTask {
  const PracticeTask(this.pack, this.item, this.type);

  final Pack pack;
  final PackItem item;
  final ExerciseType type;

  String get key => progressKey(pack.id, item.id);
}

/// Picks what to practise: items that are due first, then new ones, then the
/// rest, least recently seen first.
///
/// In a mixed session ("today's practice") each item gets the exercise that
/// suits how well it is known, from easiest to hardest: hear it and say it back,
/// pick its picture, read it, then name it or finish the sentence unaided. This
/// keeps practice mostly successful, which matters more than difficulty.
class SessionPlanner {
  const SessionPlanner();

  List<PracticeTask> plan({
    required List<Pack> packs,
    required Map<String, ItemProgress> progress,
    required int count,
    required DateTime now,
    ExerciseType? only,
    math.Random? random,
  }) {
    final candidates = <({Pack pack, PackItem item, ItemProgress state})>[];
    final seen = <String>{};
    for (final pack in packs) {
      for (final item in pack.items) {
        final usable = only == null
            ? pack.exercises.any(item.supports)
            : pack.exercises.contains(only) && item.supports(only);
        if (!usable) continue;
        final key = progressKey(pack.id, item.id);
        if (!seen.add(key)) continue;
        candidates.add((pack: pack, item: item, state: progress[key] ?? const ItemProgress()));
      }
    }

    int group(ItemProgress p) => p.isNew ? 1 : (p.isDue(now) ? 0 : 2);
    final order = {for (var i = 0; i < candidates.length; i++) candidates[i].item: i};
    candidates.sort((a, b) {
      final g = group(a.state).compareTo(group(b.state));
      if (g != 0) return g;
      if (!a.state.isNew && !b.state.isNew) {
        final byDue = (a.state.due ?? now).compareTo(b.state.due ?? now);
        if (byDue != 0 && group(a.state) == 0) return byDue;
        final bySeen = (a.state.lastSeen ?? now).compareTo(b.state.lastSeen ?? now);
        if (bySeen != 0) return bySeen;
      }
      return order[a.item]!.compareTo(order[b.item]!);
    });

    final chosen = candidates.take(count).toList();
    // Light shuffle so the same words don't always come in the same order,
    // while the due words still come in this session.
    if (random != null) chosen.shuffle(random);

    return [
      for (final c in chosen) PracticeTask(c.pack, c.item, only ?? exerciseFor(c.pack, c.item, c.state)),
    ];
  }

  /// The exercise for [item] in a mixed session, by how well it is known.
  static ExerciseType exerciseFor(Pack pack, PackItem item, ItemProgress state) {
    bool can(ExerciseType t) => pack.exercises.contains(t) && item.supports(t);
    final ladder = switch (state.box) {
      0 => const [ExerciseType.repeat, ExerciseType.listen, ExerciseType.read, ExerciseType.complete, ExerciseType.name],
      1 => const [ExerciseType.listen, ExerciseType.repeat, ExerciseType.read, ExerciseType.complete, ExerciseType.name],
      2 => const [ExerciseType.read, ExerciseType.complete, ExerciseType.repeat, ExerciseType.name, ExerciseType.listen],
      _ => const [ExerciseType.name, ExerciseType.complete, ExerciseType.read, ExerciseType.repeat, ExerciseType.listen],
    };
    for (final type in ladder) {
      if (can(type)) return type;
    }
    return pack.exercises.firstWhere(item.supports);
  }

  /// Picture choices for a listening turn: the answer plus [count] - 1 others
  /// from the same pack with different pictures and words, in random order.
  static List<PackItem> choicesFor(Pack pack, PackItem answer, int count, math.Random random) {
    final others = pack.items
        .where((i) => i.hasImage && i.id != answer.id && i.image != answer.image && i.answer != answer.answer)
        .toList()
      ..shuffle(random);
    // Prefer pictures from another category first, so the choice is about the
    // word rather than a fine distinction (an easier, errorless start).
    others.sort((a, b) {
      final aSame = a.category != null && a.category == answer.category ? 1 : 0;
      final bSame = b.category != null && b.category == answer.category ? 1 : 0;
      return aSame.compareTo(bSame);
    });
    final choices = [answer, ...others.take(math.max(1, count - 1))]..shuffle(random);
    return choices;
  }
}

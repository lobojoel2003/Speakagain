import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How an item went in one practice turn.
enum Outcome {
  /// Said (or chosen) without any help.
  independent,

  /// Said after a meaning or first-sound hint.
  withHint,

  /// Said after hearing the word (or chosen after hearing it again).
  withModel,

  /// Moved on without saying it.
  skipped;

  bool get succeeded => this != Outcome.skipped;
}

/// Days until an item is due again, by box. Items move up a box when said
/// without help and down when they needed the whole word.
const List<int> reviewIntervalsDays = [0, 1, 2, 4, 7, 14];

@immutable
class ItemProgress {
  const ItemProgress({this.box = 0, this.attempts = 0, this.independent = 0, this.helped = 0, this.lastSeen, this.due});

  final int box;
  final int attempts;
  final int independent;
  final int helped;
  final DateTime? lastSeen;
  final DateTime? due;

  bool get isNew => attempts == 0;

  /// Said without help more than once and spaced out, so it's getting easier.
  bool get isEasier => box >= 3;

  bool isDue(DateTime now) => due == null || !due!.isAfter(now);

  ItemProgress record(Outcome outcome, DateTime now) {
    final newBox = switch (outcome) {
      Outcome.independent => math.min(box + 1, reviewIntervalsDays.length - 1),
      Outcome.withHint => box,
      Outcome.withModel || Outcome.skipped => math.max(box - 1, 0),
    };
    final today = DateTime(now.year, now.month, now.day);
    return ItemProgress(
      box: newBox,
      attempts: attempts + 1,
      independent: independent + (outcome == Outcome.independent ? 1 : 0),
      helped: helped + (outcome == Outcome.withHint || outcome == Outcome.withModel ? 1 : 0),
      lastSeen: now,
      due: today.add(Duration(days: reviewIntervalsDays[newBox])),
    );
  }

  Map<String, Object?> toJson() => {
    'b': box,
    'a': attempts,
    'i': independent,
    'h': helped,
    if (lastSeen != null) 's': lastSeen!.millisecondsSinceEpoch,
    if (due != null) 'd': due!.millisecondsSinceEpoch,
  };

  factory ItemProgress.fromJson(Map<String, Object?> json) {
    DateTime? time(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    int number(Object? v) => v is int ? v : 0;
    return ItemProgress(
      box: number(json['b']).clamp(0, reviewIntervalsDays.length - 1),
      attempts: number(json['a']),
      independent: number(json['i']),
      helped: number(json['h']),
      lastSeen: time(json['s']),
      due: time(json['d']),
    );
  }
}

/// One day's practice, for the progress screen.
@immutable
class DayLog {
  const DayLog({required this.date, this.practised = 0, this.independent = 0, this.helped = 0});

  /// `yyyy-mm-dd` in local time.
  final String date;
  final int practised;
  final int independent;
  final int helped;

  DayLog add(Outcome outcome) => DayLog(
    date: date,
    practised: practised + 1,
    independent: independent + (outcome == Outcome.independent ? 1 : 0),
    helped: helped + (outcome == Outcome.withHint || outcome == Outcome.withModel ? 1 : 0),
  );

  Map<String, Object?> toJson() => {'date': date, 'p': practised, 'i': independent, 'h': helped};

  factory DayLog.fromJson(Map<String, Object?> json) => DayLog(
    date: json['date'] as String? ?? '',
    practised: json['p'] as int? ?? 0,
    independent: json['i'] as int? ?? 0,
    helped: json['h'] as int? ?? 0,
  );
}

String dayKey(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

String progressKey(String packId, String itemId) => '$packId/$itemId';

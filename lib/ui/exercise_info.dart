import '../l10n/app_localizations.dart';
import '../models/pack.dart';

/// Title, description, instruction and symbol for each exercise.
extension ExerciseText on ExerciseType {
  String title(AppLocalizations l) => switch (this) {
    ExerciseType.name => l.exerciseName,
    ExerciseType.listen => l.exerciseListen,
    ExerciseType.read => l.exerciseRead,
    ExerciseType.repeat => l.exerciseRepeat,
    ExerciseType.complete => l.exerciseComplete,
  };

  String hint(AppLocalizations l) => switch (this) {
    ExerciseType.name => l.exerciseNameHint,
    ExerciseType.listen => l.exerciseListenHint,
    ExerciseType.read => l.exerciseReadHint,
    ExerciseType.repeat => l.exerciseRepeatHint,
    ExerciseType.complete => l.exerciseCompleteHint,
  };

  String instruction(AppLocalizations l) => switch (this) {
    ExerciseType.name => l.instructionName,
    ExerciseType.listen => l.instructionListen,
    ExerciseType.read => l.instructionRead,
    ExerciseType.repeat => l.instructionRepeat,
    ExerciseType.complete => l.instructionComplete,
  };

  /// OpenMoji symbol shown on the exercise's card.
  String get symbol => switch (this) {
    ExerciseType.name => '1F5BC', // framed picture
    ExerciseType.listen => '1F442', // ear
    ExerciseType.read => '1F4D6', // open book
    ExerciseType.repeat => '1F5E3', // speaking head
    ExerciseType.complete => '1F9E9', // puzzle piece
  };
}

/// Varied praise, so success doesn't feel mechanical.
String praise(AppLocalizations l, int index) => switch (index % 5) {
  0 => l.praise1,
  1 => l.praise2,
  2 => l.praise3,
  3 => l.praise4,
  _ => l.praise5,
};

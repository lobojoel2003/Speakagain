import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/answer_matcher.dart';
import '../../core/session_planner.dart';
import '../../l10n/app_localizations.dart';
import '../../models/pack.dart';
import '../../models/progress.dart';
import '../../services/speech/recorder.dart';
import '../../services/speech/speech_services.dart';
import '../exercise_info.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback_banner.dart';
import '../widgets/mic_button.dart';
import 'summary_screen.dart';

/// Runs a practice session: one task after another, then a summary.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.tasks, this.only});

  final List<PracticeTask> tasks;

  /// The exercise chosen on the home screen, or null for today's mixed practice.
  final ExerciseType? only;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int _index = 0;
  final List<Outcome> _outcomes = [];

  Future<void> _finished(Outcome outcome) async {
    final task = widget.tasks[_index];
    _outcomes.add(outcome);
    await context.read<AppState>().record(task, outcome);
    if (!mounted) return;
    if (_index + 1 >= widget.tasks.length) {
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SummaryScreen(outcomes: _outcomes, only: widget.only),
          ),
        ),
      );
    } else {
      setState(() => _index++);
    }
  }

  void _exit() {
    if (_outcomes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SummaryScreen(outcomes: _outcomes, only: widget.only),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final task = widget.tasks[_index];
    final total = widget.tasks.length;
    return PopScope(
      canPop: _outcomes.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _exit,
                          icon: const Icon(Icons.home_rounded, size: 30),
                          label: Text(l.finishForNow, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(l.practiceProgress(_index + 1, total), style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: (_index) / total, minHeight: 10),
                ),
              ),
              Expanded(
                child: task.type == ExerciseType.listen
                    ? ListenExercise(key: ValueKey('${task.key}-$_index'), task: task, onFinished: _finished)
                    : SpokenExercise(key: ValueKey('${task.key}-$_index'), task: task, onFinished: _finished),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Phase { ready, listening, checking, done }

/// Naming, reading aloud, repeating and finishing sentences: the person
/// speaks, and the answer is checked on the device (or confirmed by them).
///
/// Help follows the usual cueing order in aphasia therapy, from least to most:
/// a meaning hint, the first sound, then the whole word to repeat. The person
/// can ask for help at any time, and it is offered after a try that wasn't
/// caught.
class SpokenExercise extends StatefulWidget {
  const SpokenExercise({super.key, required this.task, required this.onFinished});

  final PracticeTask task;
  final ValueChanged<Outcome> onFinished;

  @override
  State<SpokenExercise> createState() => _SpokenExerciseState();
}

class _SpokenExerciseState extends State<SpokenExercise> {
  late final SpeechServices _speech = context.read<AppState>().speech;
  _Phase _phase = _Phase.ready;
  int _attempts = 0;
  int _hintLevel = 0;
  bool _heardModel = false;
  bool _showWord = false;
  bool _micDenied = false;
  bool _askedMic = false;
  Recording? _lastRecording;
  FeedbackKind? _feedbackKind;
  String? _feedback;
  String? _feedbackDetail;
  final int _praiseIndex = math.Random().nextInt(5);
  final ScrollController _scroll = ScrollController();

  PracticeTask get task => widget.task;
  PackItem get item => task.item;
  ExerciseType get type => task.type;

  @override
  void initState() {
    super.initState();
    _showWord = type == ExerciseType.read || type == ExerciseType.repeat;
    WidgetsBinding.instance.addPostFrameCallback((_) => _introduce());
  }

  @override
  void dispose() {
    unawaited(_speech.cancelListening());
    unawaited(_speech.stopSpeaking());
    _scroll.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // Keep the newest feedback or hint in view on small screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String get _speakableSentence => (item.sentence ?? '').replaceAll(blank, '…');

  Future<void> _introduce() async {
    final app = context.read<AppState>();
    final l = AppLocalizations.of(context);
    if (app.settings.speakInstructions) await _speech.speak(type.instruction(l));
    if (!mounted) return;
    if (type == ExerciseType.repeat) {
      await _speech.speak(item.answer);
    } else if (type == ExerciseType.complete && app.settings.speakInstructions) {
      await _speech.speak(_speakableSentence);
    }
  }

  bool get _selfCheck => !_speech.canCheckSpeech || !_speech.canRecord || _micDenied;

  Future<void> _onMic() async {
    if (_phase == _Phase.listening) {
      await _speech.stopListening();
      return;
    }
    if (_phase != _Phase.ready) return;
    if (!_askedMic) {
      _askedMic = true;
      final allowed = await _speech.ensureMicrophone();
      if (!allowed) {
        setState(() => _micDenied = true);
        return;
      }
    }
    await _speech.stopSpeaking();
    setState(() {
      _phase = _Phase.listening;
      _feedbackKind = null;
    });
    final Recording recording;
    try {
      recording = await _speech.listen();
    } on Object {
      if (mounted) setState(() => _micDenied = true);
      if (mounted) setState(() => _phase = _Phase.ready);
      return;
    }
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (!recording.heardSpeech) {
      setState(() {
        _phase = _Phase.ready;
        _feedbackKind = FeedbackKind.info;
        _feedback = l.noSpeechHeard;
        _feedbackDetail = null;
      });
      return;
    }
    setState(() => _phase = _Phase.checking);
    String heard;
    try {
      heard = await _speech.transcribe(recording);
    } on Object {
      heard = '';
    }
    if (!mounted) return;
    final app = context.read<AppState>();
    final check = AnswerMatcher(strictness: app.settings.strictness)
        .check(heard: heard, answers: item.answers, language: task.pack.language);
    _attempts++;
    _lastRecording = recording;
    if (check.level == MatchLevel.said) {
      _succeed();
      return;
    }
    setState(() {
      _phase = _Phase.ready;
      _feedbackKind = FeedbackKind.nearly;
      if (check.level == MatchLevel.nearly) {
        _feedback = l.nearly;
      } else {
        _feedback = heard.isEmpty ? l.notCaught : l.keepGoing;
      }
      _feedbackDetail = heard.isEmpty ? null : l.heardYouSay(heard);
    });
    if (app.settings.autoHints) await _autoHelp();
  }

  Future<void> _autoHelp() async {
    if (_attempts >= 3 || _hintLevel >= 2) {
      await _sayTogether();
    } else {
      await _nextHint();
    }
  }

  bool get _hasMeaningHint => (type == ExerciseType.complete && item.hasImage) || task.pack.cueFor(item) != null;

  /// Reveals the next hint: meaning, then first sound, then the word itself.
  Future<void> _nextHint() async {
    var level = _hintLevel + 1;
    if (level == 1 && !_hasMeaningHint) level = 2;
    if (level >= 3) {
      await _sayTogether();
      return;
    }
    setState(() => _hintLevel = level);
    if (level == 1) {
      final cue = task.pack.cueFor(item);
      if (cue != null) await _speech.speak(cue);
    }
  }

  Future<void> _sayTogether() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _hintLevel = 3;
      _heardModel = true;
      _showWord = true;
      if (_feedbackKind == null || _feedbackKind == FeedbackKind.info) {
        _feedbackKind = FeedbackKind.info;
        _feedback = l.sayTogether;
        _feedbackDetail = null;
      } else {
        _feedbackDetail = l.sayTogether;
      }
    });
    await _speech.speak(item.answer);
  }

  Future<void> _hearIt() async {
    if (type != ExerciseType.repeat) {
      setState(() {
        _heardModel = true;
        _showWord = true;
      });
    }
    await _speech.speak(item.answer);
  }

  void _succeed() {
    final l = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    unawaited(_speech.playChime());
    setState(() {
      _phase = _Phase.done;
      _showWord = true;
      _feedbackKind = FeedbackKind.success;
      _feedback = praise(l, _praiseIndex + _attempts);
      _feedbackDetail = null;
    });
  }

  Outcome get _outcome {
    if (type == ExerciseType.repeat) return _hintLevel >= 1 && _hintLevel < 3 ? Outcome.withHint : Outcome.independent;
    if (_heardModel) return Outcome.withModel;
    if (_hintLevel > 0) return Outcome.withHint;
    return Outcome.independent;
  }

  String get _firstLetterPattern {
    final chars = item.answer.characters;
    final first = chars.first.toUpperCase();
    if (!task.pack.language.startsWith('zh') && chars.length > 1) {
      return '$first ${List.filled(chars.length - 1, '_').join(' ')}';
    }
    return first;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SpeakColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final busy = _feedbackKind != null || (_hintLevel > 0 && _phase != _Phase.done);
    // Smaller once hints or feedback appear, so everything fits without scrolling.
    final pictureSize = math.min(size.width * 0.62, size.height * (busy ? 0.2 : 0.3)).clamp(110.0, 340.0);
    final done = _phase == _Phase.done;
    final cue = task.pack.cueFor(item);

    Widget stimulus() {
      final children = <Widget>[];
      final showPicture =
          item.hasImage &&
          (type == ExerciseType.name ||
              type == ExerciseType.repeat ||
              (type == ExerciseType.complete && (_hintLevel >= 1 || done)) ||
              (type == ExerciseType.read && (_hintLevel >= 1 || done)));
      if (showPicture) {
        children.add(
          PackImage(
            pack: task.pack,
            reference: item.image!,
            size: type == ExerciseType.name ? pictureSize : pictureSize * 0.75,
            semanticLabel: _showWord ? item.answer : null,
          ),
        );
        children.add(const SizedBox(height: 12));
      }
      if (type == ExerciseType.complete) {
        final parts = item.sentence!.split(blank);
        children.add(
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: parts.first),
                if (done || _showWord)
                  TextSpan(
                    text: item.answer,
                    style: TextStyle(
                      color: done ? colors.success : theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  TextSpan(
                    // Figure spaces, underlined: a calm line where the word goes.
                    text: ' \u2007\u2007\u2007\u2007\u2007 ',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      decorationColor: theme.colorScheme.primary,
                      decorationThickness: 2.5,
                    ),
                  ),
                TextSpan(text: parts.length > 1 ? parts[1] : ''),
              ],
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge,
          ),
        );
      } else if (_showWord) {
        children.add(
          Text(
            item.answer,
            textAlign: TextAlign.center,
            style: (item.answer.length > 14 ? theme.textTheme.displaySmall : theme.textTheme.displayMedium)?.copyWith(
              color: done ? colors.success : theme.colorScheme.onSurface,
            ),
          ),
        );
      }
      return Column(mainAxisSize: MainAxisSize.min, children: children);
    }

    Widget hints() {
      final rows = <Widget>[];
      if (_hintLevel >= 1 && !done) {
        if (cue != null && type != ExerciseType.complete) {
          rows.add(_HintChip(icon: Icons.lightbulb_outline_rounded, text: cue));
        } else if (cue != null && type == ExerciseType.complete && !item.hasImage) {
          rows.add(_HintChip(icon: Icons.lightbulb_outline_rounded, text: cue));
        }
      }
      if (_hintLevel >= 2 && !done && !_showWord) {
        rows.add(
          _HintChip(
            icon: Icons.record_voice_over_rounded,
            text: l.hintStartsWith(item.answer.characters.first.toUpperCase()),
            large: _firstLetterPattern,
          ),
        );
      }
      return Column(
        children: [for (final r in rows) Padding(padding: const EdgeInsets.only(top: 10), child: r)],
      );
    }

    final selfCheck = _selfCheck;
    final selfCheckNote = !_speech.canRecord
        ? l.speechSetupWeb
        : _micDenied
        ? l.micOff
        : l.speechCheckOff;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: pagePadding(context),
            child: ReadableWidth(
              child: Column(
                children: [
                  SpokenInstruction(
                    text: type.instruction(l),
                    onSpeak: () =>
                        _speech.speak(type == ExerciseType.complete ? _speakableSentence : type.instruction(l)),
                  ),
                  const SizedBox(height: 16),
                  stimulus(),
                  hints(),
                  if (_feedbackKind != null) ...[
                    const SizedBox(height: 16),
                    FeedbackBanner(
                      kind: _feedbackKind!,
                      message: _feedback!,
                      detail: _feedbackDetail,
                      action: _lastRecording != null && _lastRecording!.samples.isNotEmpty
                          ? TextButton.icon(
                              onPressed: _phase == _Phase.ready || done
                                  ? () => _speech.playRecording(_lastRecording!)
                                  : null,
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                              icon: const Icon(Icons.replay_rounded),
                              label: Text(l.hearMyAnswer),
                            )
                          : null,
                    ),
                  ] else if (selfCheck && !done) ...[
                    const SizedBox(height: 16),
                    Text(selfCheckNote, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Everything you press is down here, within reach of one thumb.
        ReadableWidth(
          maxWidth: 640,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (done)
                  BigButton(
                    icon: Icons.arrow_forward_rounded,
                    label: l.nextButton,
                    onPressed: () => widget.onFinished(_outcome),
                    color: colors.success,
                    foreground: colors.onSuccess,
                  )
                else if (selfCheck)
                  BigButton(icon: Icons.check_rounded, label: l.iSaidIt, onPressed: _succeed)
                else
                  MicButton(
                    state: switch (_phase) {
                      _Phase.listening => MicState.listening,
                      _Phase.checking => MicState.checking,
                      _ => MicState.ready,
                    },
                    level: _speech.inputLevel,
                    onPressed: _phase == _Phase.checking ? null : _onMic,
                    label: switch (_phase) {
                      _Phase.listening => l.tapWhenDone,
                      _Phase.checking => l.checking,
                      _ => _attempts > 0 ? l.tryAgainButton : l.tapToSpeak,
                    },
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!done && type != ExerciseType.repeat)
                      HelperButton(
                        icon: Icons.lightbulb_outline_rounded,
                        label: l.hintButton,
                        highlight: _feedbackKind == FeedbackKind.nearly && _hintLevel < 3,
                        onPressed: _phase == _Phase.ready && _hintLevel < 3 ? _nextHint : null,
                      ),
                    HelperButton(
                      icon: Icons.volume_up_rounded,
                      label: type == ExerciseType.repeat || done ? l.hearAgainButton : l.hearItButton,
                      onPressed: _phase == _Phase.listening || _phase == _Phase.checking ? null : _hearIt,
                    ),
                    if (!done && !selfCheck && _attempts > 0)
                      HelperButton(
                        icon: Icons.check_rounded,
                        label: l.iSaidIt,
                        onPressed: _phase == _Phase.ready ? _succeed : null,
                      ),
                    if (!done)
                      HelperButton(
                        icon: Icons.skip_next_rounded,
                        label: l.skipButton,
                        onPressed: _phase == _Phase.listening || _phase == _Phase.checking
                            ? null
                            : () => widget.onFinished(Outcome.skipped),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.icon, required this.text, this.large});

  final IconData icon;
  final String text;
  final String? large;

  @override
  Widget build(BuildContext context) {
    final colors = SpeakColors.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colors.calmSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.calm, width: colors.cardBorderWidth > 2 ? 3 : 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.calm, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.titleLarge),
                if (large != null)
                  Text(large!, style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 4, color: colors.calm)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Listen and choose: hear a word, tap its picture. No speaking needed, so
/// it suits people whose understanding needs practice too, and it works in
/// any browser.
class ListenExercise extends StatefulWidget {
  const ListenExercise({super.key, required this.task, required this.onFinished});

  final PracticeTask task;
  final ValueChanged<Outcome> onFinished;

  @override
  State<ListenExercise> createState() => _ListenExerciseState();
}

class _ListenExerciseState extends State<ListenExercise> {
  late final SpeechServices _speech = context.read<AppState>().speech;
  late final List<PackItem> _choices;
  final Set<String> _ruledOut = {};
  bool _done = false;
  final int _praiseIndex = math.Random().nextInt(5);
  String? _message;
  FeedbackKind? _kind;

  @override
  void initState() {
    super.initState();
    final count = context.read<AppState>().settings.pictureChoices;
    _choices = SessionPlanner.choicesFor(widget.task.pack, widget.task.item, count, math.Random());
    WidgetsBinding.instance.addPostFrameCallback((_) => _introduce());
  }

  @override
  void dispose() {
    unawaited(_speech.stopSpeaking());
    super.dispose();
  }

  Future<void> _introduce() async {
    final app = context.read<AppState>();
    final l = AppLocalizations.of(context);
    if (app.settings.speakInstructions) await _speech.speak(l.instructionListen);
    if (mounted) await _speech.speak(widget.task.item.answer);
  }

  Future<void> _choose(PackItem choice) async {
    if (_done || _ruledOut.contains(choice.id)) return;
    final l = AppLocalizations.of(context);
    if (choice.id == widget.task.item.id) {
      HapticFeedback.mediumImpact();
      unawaited(_speech.playChime());
      setState(() {
        _done = true;
        _kind = FeedbackKind.success;
        _message = praise(l, _praiseIndex);
      });
      return;
    }
    setState(() {
      _ruledOut.add(choice.id);
      _kind = FeedbackKind.nearly;
      _message = l.listenNotThat;
    });
    await _speech.speak(widget.task.item.answer);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SpeakColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = _choices.length <= 2 || width > 700 ? math.min(_choices.length, width > 700 ? 4 : 2) : 2;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: pagePadding(context),
            child: ReadableWidth(
              child: Column(
                children: [
                  SpokenInstruction(text: l.instructionListen, onSpeak: () => _speech.speak(l.instructionListen)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cell = (constraints.maxWidth - (columns - 1) * 14) / columns;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final choice in _choices)
                            SizedBox(
                              width: cell,
                              child: _ChoiceCard(
                                task: widget.task,
                                choice: choice,
                                state: _done && choice.id == widget.task.item.id
                                    ? _ChoiceState.correct
                                    : _ruledOut.contains(choice.id) || _done
                                    ? _ChoiceState.dimmed
                                    : _ChoiceState.open,
                                onTap: () => _choose(choice),
                                size: math.min(cell - 36, 220),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (_kind != null) ...[
                    const SizedBox(height: 16),
                    FeedbackBanner(kind: _kind!, message: _message!, detail: _done ? widget.task.item.answer : null),
                  ],
                ],
              ),
            ),
          ),
        ),
        ReadableWidth(
          maxWidth: 640,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_done)
                  BigButton(
                    icon: Icons.arrow_forward_rounded,
                    label: l.nextButton,
                    color: colors.success,
                    foreground: colors.onSuccess,
                    onPressed: () => widget.onFinished(_ruledOut.isEmpty ? Outcome.independent : Outcome.withModel),
                  )
                else
                  BigButton(
                    icon: Icons.volume_up_rounded,
                    label: l.hearAgainButton,
                    onPressed: () => _speech.speak(widget.task.item.answer),
                  ),
                const SizedBox(height: 12),
                if (!_done)
                  Row(
                    children: [
                      HelperButton(
                        icon: Icons.skip_next_rounded,
                        label: l.skipButton,
                        onPressed: () => widget.onFinished(Outcome.skipped),
                      ),
                    ],
                  ),
                if (_done) Text(' ', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _ChoiceState { open, correct, dimmed }

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.task,
    required this.choice,
    required this.state,
    required this.onTap,
    required this.size,
  });

  final PracticeTask task;
  final PackItem choice;
  final _ChoiceState state;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = SpeakColors.of(context);
    final correct = state == _ChoiceState.correct;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: state == _ChoiceState.dimmed ? 0.3 : 1,
      child: SpeakCard(
        onTap: state == _ChoiceState.open ? onTap : null,
        borderColor: correct ? colors.success : null,
        borderWidth: correct ? 5 : null,
        color: correct ? colors.successSoft : null,
        padding: const EdgeInsets.all(14),
        semanticLabel: correct ? choice.answer : null,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: PackImage(pack: task.pack, reference: choice.image!, size: size),
            ),
            if (correct) Icon(Icons.check_circle_rounded, color: colors.success, size: 44),
          ],
        ),
      ),
    );
  }
}

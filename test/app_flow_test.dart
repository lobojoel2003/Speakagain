import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakagain/app.dart';
import 'package:speakagain/app_state.dart';
import 'package:speakagain/models/pack.dart';
import 'package:speakagain/models/progress.dart';
import 'package:speakagain/models/settings.dart';
import 'package:speakagain/ui/screens/practice_screen.dart';
import 'package:speakagain/ui/theme.dart';
import 'package:speakagain/ui/widgets/feedback_banner.dart';

import 'support/fakes.dart';

Future<void> pumpApp(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SpeakagainApp(state: state));
  await tester.pumpAndSettle();
}

Future<void> startExercise(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(find.text(title), 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  final morning = DateTime(2026, 11, 13, 9, 30);

  testWidgets('first start: language, sound check, speech checking, ready', (tester) async {
    final state = await createTestState(
      settings: const AppSettings(language: 'en'),
      clock: () => morning,
    );
    await pumpApp(tester, state);

    expect(find.text('Welcome'), findsOneWidget);
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    // The app switches to Spanish straight away.
    expect(find.text('Elige tu idioma'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();
    expect((state.speech as FakeSpeechServices).spoken, contains('Hola'));
    await tester.tap(find.text('Sí, lo oigo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(state.settings.onboarded, isTrue);
    expect(state.settings.language, 'es');
    expect(find.text('Buenos días'), findsOneWidget);
    expect(find.text('Práctica de hoy'), findsOneWidget);
  });

  testWidgets('naming: a hint after a miss, then success', (tester) async {
    final speech = FakeSpeechServices();
    final state = await createTestState(speech: speech, clock: () => morning);
    await pumpApp(tester, state);
    await startExercise(tester, 'Name the picture');

    final task = (tester.widget(find.byType(SpokenExercise)) as SpokenExercise).task;
    expect(task.type, ExerciseType.name);
    expect(find.text('What is this?'), findsOneWidget);

    speech.heard.addAll(['something else', task.item.answer]);
    await tester.tap(find.text('Tap, then speak'));
    await tester.pumpAndSettle();
    expect(find.text('Good try. Let\'s try again.'), findsOneWidget);
    expect(find.text('I heard “something else”'), findsOneWidget);
    // The meaning hint was offered and read out.
    expect(find.text(task.pack.cueFor(task.item)!), findsOneWidget);
    expect(speech.spoken, contains(task.pack.cueFor(task.item)));

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is FeedbackBanner && w.kind == FeedbackKind.success), findsOneWidget);
    expect(speech.chimes, 1);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final progress = state.progress[task.key]!;
    expect(progress.attempts, 1);
    expect(progress.helped, 1);
    expect(state.today.practised, 1);
  });

  testWidgets('nothing heard: a gentle prompt, no attempt counted', (tester) async {
    final speech = FakeSpeechServices()..nextSilent = true;
    final state = await createTestState(speech: speech, clock: () => morning);
    await pumpApp(tester, state);
    await startExercise(tester, 'Read aloud');
    await tester.tap(find.text('Tap, then speak'));
    await tester.pumpAndSettle();
    expect(find.text("I didn't hear anything. Tap the microphone and speak."), findsOneWidget);
    expect(find.text('Tap, then speak'), findsOneWidget);
  });

  testWidgets('listening: a wrong picture fades, the right one is praised', (tester) async {
    final speech = FakeSpeechServices();
    final state = await createTestState(speech: speech, clock: () => morning);
    await pumpApp(tester, state);
    await startExercise(tester, 'Listen and choose');

    final task = (tester.widget(find.byType(ListenExercise)) as ListenExercise).task;
    expect(speech.spoken.last, task.item.answer);

    final cards = find.descendant(of: find.byType(ListenExercise), matching: find.byType(InkWell));
    // Tap cards until the right one: wrong ones never show a cross or red.
    var tapped = 0;
    while (find.byWidgetPredicate((w) => w is FeedbackBanner && w.kind == FeedbackKind.success).evaluate().isEmpty) {
      await tester.tap(cards.at(tapped++), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final outcome = state.progress[task.key]!;
    expect(outcome.attempts, 1);
  });

  testWidgets('without speech checking the person confirms with "I said it"', (tester) async {
    final speech = FakeSpeechServices(checking: false);
    final state = await createTestState(speech: speech, clock: () => morning);
    await pumpApp(tester, state);
    await startExercise(tester, 'Say it after me');

    final task = (tester.widget(find.byType(SpokenExercise)) as SpokenExercise).task;
    expect(speech.spoken, contains(task.item.answer));
    expect(find.text('Say it, then tap “I said it”.'), findsOneWidget);
    await tester.tap(find.text('I said it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(state.progress[task.key]!.independent, 1);
  });

  testWidgets('a whole session ends with a summary and shows on Progress', (tester) async {
    final speech = FakeSpeechServices(checking: false);
    final state = await createTestState(
      speech: speech,
      clock: () => morning,
      settings: const AppSettings(language: 'en', onboarded: true, speakInstructions: false, sessionLength: 5),
    );
    await pumpApp(tester, state);
    await tester.tap(find.text("Today's practice"));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      if (find.byType(ListenExercise).evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
      } else {
        await tester.tap(find.text('I said it'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
      }
      await tester.pumpAndSettle();
    }
    expect(find.text('Well done!'), findsOneWidget);
    expect(find.textContaining('You practised 5 words'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('1 day of practice'), findsOneWidget);
    expect(state.days.single.practised, 5);
  });

  testWidgets('settings change the text size and colours', (tester) async {
    final state = await createTestState(clock: () => morning);
    await pumpApp(tester, state);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Largest'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Largest'));
    await tester.pumpAndSettle();
    expect(state.settings.textSize, TextSizeChoice.largest);
    await tester.scrollUntilVisible(find.text('High contrast'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('High contrast'));
    await tester.pumpAndSettle();
    expect(state.settings.theme, ThemeChoice.contrast);
    expect(Theme.of(tester.element(find.text('High contrast'))).colorScheme.surface, const Color(0xFF000000));
  });

  testWidgets('every language has its packs and app text', (tester) async {
    for (final code in ['ar', 'hi', 'zh', 'pl']) {
      final state = await createTestState(
        settings: AppSettings(language: code, onboarded: true, speakInstructions: false),
        clock: () => morning,
      );
      await pumpApp(tester, state);
      expect(state.currentPacks, hasLength(4), reason: code);
      expect(state.availableExercises, hasLength(ExerciseType.values.length), reason: code);
      if (code == 'ar') {
        expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.rtl);
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('no red anywhere in the themes', () {
    for (final kind in SpeakThemeKind.values) {
      final theme = buildTheme(kind);
      final s = theme.colorScheme;
      final c = theme.extension<SpeakColors>()!;
      for (final color in [
        s.primary,
        s.secondary,
        s.tertiary,
        s.error,
        s.surface,
        c.success,
        c.nearly,
        c.calm,
        c.nearlySoft,
      ]) {
        final hsl = HSLColor.fromColor(color);
        final reddish =
            (hsl.hue < 20 || hsl.hue > 340) && hsl.saturation > 0.35 && hsl.lightness > 0.15 && hsl.lightness < 0.85;
        expect(reddish, isFalse, reason: '$kind uses a red: $color');
      }
    }
  });

  test('outcomes are recorded per day', () async {
    final state = await createTestState(clock: () => morning);
    final pack = state.currentPacks.first;
    final task = state.planSession(seed: 1).first;
    expect(task.pack.language, pack.language);
    await state.record(task, Outcome.independent);
    await state.record(task, Outcome.skipped);
    expect(state.today.practised, 2);
    expect(state.lastSevenDays.last, isTrue);
    await state.resetProgress();
    expect(state.progress, isEmpty);
  });
}

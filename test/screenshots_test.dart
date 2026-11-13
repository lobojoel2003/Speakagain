@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakagain/app.dart';
import 'package:speakagain/app_state.dart';
import 'package:speakagain/core/session_planner.dart';
import 'package:speakagain/models/pack.dart';
import 'package:speakagain/models/progress.dart';
import 'package:speakagain/models/settings.dart';
import 'package:speakagain/ui/screens/practice_screen.dart';

import 'support/fakes.dart';

/// Renders the screens used in README.md into build/screenshots/, with the
/// app's real font and symbols, at a phone size (412 x 915 dp, 2x pixels).
void main() {
  const size = Size(412, 915);
  const pixelRatio = 2.0;
  final boundary = GlobalKey();
  var clockTime = DateTime(2026, 11, 13, 10, 5);

  setUpAll(() async {
    final atkinson = FontLoader('Atkinson Hyperlegible')
      ..addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegible-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegible-Bold.ttf'));
    await atkinson.load();
    final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
  }

  Future<AppState> open(WidgetTester tester, AppSettings settings, {FakeSpeechServices? speech}) async {
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);
    final state = (await tester.runAsync(
      () => createTestState(settings: settings, speech: speech ?? FakeSpeechServices(), clock: () => clockTime),
    ))!;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: SpeakagainApp(state: state),
      ),
    );
    await settle(tester);
    return state;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await settle(tester);
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> startExercise(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(find.text(title), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await settle(tester);
  }

  /// A week of practice history, so the progress screen has something to show.
  Future<void> history(WidgetTester tester, AppState state) async {
    final words = state.currentPacks.firstWhere((p) => p.id.endsWith('everyday-words'));
    await tester.runAsync(() async {
      for (final (day, count) in [(9, 8), (10, 10), (11, 6), (13, 7)]) {
        clockTime = DateTime(2026, 11, day, 9);
        for (var i = 0; i < count; i++) {
          final item = words.items[i];
          final outcome = i % 3 == 2 ? Outcome.withHint : Outcome.independent;
          await state.record(_task(words, item), outcome);
        }
      }
    });
    clockTime = DateTime(2026, 11, 13, 10, 5);
  }

  const english = AppSettings(language: 'en', onboarded: true, speakInstructions: false, sessionLength: 10);

  testWidgets('home', (tester) async {
    final state = await open(tester, english);
    await history(tester, state);
    await tester.pumpAndSettle();
    await shoot(tester, '1-home');
  });

  testWidgets('naming with a hint', (tester) async {
    final speech = FakeSpeechServices();
    await open(tester, english, speech: speech);
    await startExercise(tester, 'Name the picture');
    final task = (tester.widget(find.byType(SpokenExercise)) as SpokenExercise).task;
    speech.heard.add(task.item.answer.substring(0, (task.item.answer.length / 2).ceil()));
    await tester.tap(find.text('Tap, then speak'));
    await shoot(tester, '2-naming-hint');
    speech.heard.add(task.item.answer);
    await tester.tap(find.text('Try again'));
    await shoot(tester, '3-said-it');
  });

  testWidgets('listen and choose', (tester) async {
    await open(tester, english.copyWith(pictureChoices: 4));
    await startExercise(tester, 'Listen and choose');
    await shoot(tester, '4-listen');
  });

  testWidgets('finish the sentence', (tester) async {
    final speech = FakeSpeechServices();
    await open(tester, english, speech: speech);
    await startExercise(tester, 'Finish the sentence');
    await tester.tap(find.text('Hint'));
    await shoot(tester, '5-finish-sentence');
  });

  testWidgets('progress', (tester) async {
    final state = await open(tester, english);
    await history(tester, state);
    await tester.tap(find.text('Progress'));
    await shoot(tester, '6-progress');
  });

  testWidgets('dark theme', (tester) async {
    await open(tester, english.copyWith(theme: ThemeChoice.dark));
    await startExercise(tester, 'Read aloud');
    await shoot(tester, '7-dark-read-aloud');
  });

  testWidgets('high contrast', (tester) async {
    await open(tester, english.copyWith(theme: ThemeChoice.contrast));
    await startExercise(tester, 'Say it after me');
    await shoot(tester, '8-high-contrast');
  });

  testWidgets('spanish', (tester) async {
    await open(tester, english.copyWith(language: 'es'));
    await shoot(tester, '9-spanish-home');
  });

  testWidgets('settings', (tester) async {
    await open(tester, english);
    await tester.tap(find.text('Settings'));
    await shoot(tester, '10-settings');
  });

  testWidgets('onboarding', (tester) async {
    await open(tester, const AppSettings(language: 'en'));
    await shoot(tester, '11-welcome');
  });
}

PracticeTask _task(Pack pack, PackItem item) => PracticeTask(pack, item, ExerciseType.name);

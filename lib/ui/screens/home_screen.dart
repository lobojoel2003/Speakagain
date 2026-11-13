import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../models/pack.dart';
import '../exercise_info.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'practice_screen.dart';

/// Start here: one big button for today's practice, then each exercise.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _start(BuildContext context, {ExerciseType? only}) {
    final tasks = context.read<AppState>().planSession(only: only);
    if (tasks.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(tasks: tasks, only: only),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SpeakColors.of(context);
    final hour = app.now.hour;
    final greeting = hour < 12
        ? l.greetingMorning
        : hour < 18
        ? l.greetingAfternoon
        : l.greetingEvening;
    final today = app.today.practised;
    final goal = app.settings.sessionLength;
    final goalMet = today >= goal;

    return SafeArea(
      child: ListView(
        padding: pagePadding(context),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting, style: theme.textTheme.headlineLarge),
                          const SizedBox(height: 4),
                          Text(
                            goalMet ? l.todayGoalMet : l.todayCount(today),
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _TodayRing(value: goal == 0 ? 0 : (today / goal).clamp(0, 1).toDouble(), done: goalMet),
                  ],
                ),
                const SizedBox(height: 24),
                SpeakCard(
                  color: theme.colorScheme.primary,
                  borderColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  onTap: () => _start(context),
                  semanticLabel: l.startPractice,
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(color: theme.colorScheme.onPrimary, shape: BoxShape.circle),
                        child: Icon(Icons.play_arrow_rounded, size: 52, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.startPractice,
                              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.startPracticeHint,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(l.moreExercises, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final type in app.availableExercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SpeakCard(
                      onTap: () => _start(context, only: type),
                      semanticLabel: type.title(l),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: colors.calmSoft, borderRadius: BorderRadius.circular(20)),
                            child: Symbol(type.symbol),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type.title(l), style: theme.textTheme.titleLarge),
                                const SizedBox(height: 2),
                                Text(
                                  type.hint(l),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 36, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayRing extends StatelessWidget {
  const _TodayRing({required this.value, required this.done});

  final double value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = SpeakColors.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 84,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: done ? colors.success : Theme.of(context).colorScheme.primary,
              ),
            ),
            if (done)
              Icon(Icons.check_rounded, size: 44, color: colors.success)
            else
              Text('${(value * 100).round()}%', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

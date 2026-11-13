import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../models/pack.dart';
import '../../models/progress.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'practice_screen.dart';

/// The end of a session: what went well, said warmly. Effort counts as much
/// as success, so skipped words aren't counted against anyone.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.outcomes, this.only});

  final List<Outcome> outcomes;
  final ExerciseType? only;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      if (app.settings.speakInstructions) unawaited(app.speech.speak(AppLocalizations.of(context).doneTitle));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SpeakColors.of(context);
    final practised = widget.outcomes.length;
    final own = widget.outcomes.where((o) => o == Outcome.independent).length;
    final helped = widget.outcomes.where((o) => o == Outcome.withHint || o == Outcome.withModel).length;

    Widget stat(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SpeakCard(
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: theme.textTheme.titleLarge)),
          ],
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: pagePadding(context),
                child: ReadableWidth(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Symbol('1F31F', size: 150),
                      const SizedBox(height: 12),
                      Text(l.doneTitle, style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        l.donePractised(practised),
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (own > 0) stat(Icons.check_circle_rounded, colors.success, l.doneOnYourOwn(own)),
                      if (helped > 0) stat(Icons.volunteer_activism_rounded, colors.calm, l.doneWithHelp(helped)),
                      const SizedBox(height: 12),
                      Text(l.doneEffort, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
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
                    BigButton(
                      icon: Icons.replay_rounded,
                      label: l.practiseAgain,
                      onPressed: () {
                        final tasks = context.read<AppState>().planSession(only: widget.only);
                        if (tasks.isEmpty) {
                          Navigator.of(context).pop();
                          return;
                        }
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => PracticeScreen(tasks: tasks, only: widget.only),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    BigButton(
                      icon: Icons.home_rounded,
                      label: l.backHome,
                      filled: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

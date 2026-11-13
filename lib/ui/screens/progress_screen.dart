import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Practice so far, shown as encouragement: days practised and words getting
/// easier. There is no streak to break and no score to lose.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SpeakColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final week = app.lastSevenDays;
    final now = app.now;
    final easier = app.easierItems;

    Widget stat(String symbol, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SpeakCard(
        child: Row(
          children: [
            Symbol(symbol, size: 52),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: theme.textTheme.titleLarge)),
          ],
        ),
      ),
    );

    return SafeArea(
      child: ListView(
        padding: pagePadding(context),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(l.progressTitle, style: theme.textTheme.headlineLarge),
                const SizedBox(height: 20),
                Text(l.progressThisWeek, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SpeakCard(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _Day(
                            label: DateFormat.E(locale).format(DateTime(now.year, now.month, now.day - (6 - i))),
                            practised: week[i],
                            today: i == 6,
                            color: colors.success,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (app.daysPractised == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Symbol('1F331', size: 110),
                        const SizedBox(height: 12),
                        Text(l.progressEmpty, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                      ],
                    ),
                  )
                else ...[
                  stat('1F4C5', l.progressDays(app.daysPractised)),
                  stat('1F5E8', l.progressWords(app.wordsPractised)),
                  stat('1F331', l.progressEasier(easier.length)),
                  if (easier.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(l.progressEasierList, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (pack, item) in easier)
                          Chip(
                            avatar: item.hasImage ? PackImage(pack: pack, reference: item.image!, size: 30) : null,
                            label: Text(item.answer, style: theme.textTheme.titleMedium),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            side: BorderSide(color: colors.cardBorder, width: colors.cardBorderWidth),
                            backgroundColor: colors.card,
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.label, required this.practised, required this.today, required this.color});

  final String label;
  final bool practised;
  final bool today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      checked: practised,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: today ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: practised ? color : Colors.transparent,
              border: Border.all(color: practised ? color : theme.colorScheme.outline, width: today ? 3 : 2),
            ),
            child: practised ? Icon(Icons.check_rounded, size: 24, color: theme.colorScheme.surface) : null,
          ),
        ],
      ),
    );
  }
}

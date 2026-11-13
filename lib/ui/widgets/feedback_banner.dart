import 'package:flutter/material.dart';

import '../theme.dart';

enum FeedbackKind {
  /// Said it, or chose the right picture.
  success,

  /// Part of it was heard, or a gentle "let's try again".
  nearly,

  /// Information, such as a hint or "I didn't hear anything".
  info,
}

/// Encouraging feedback after an answer. Success is green with a tick; any
/// other result is warm and hopeful, never red and never a cross.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, required this.kind, required this.message, this.detail, this.action});

  final FeedbackKind kind;
  final String message;
  final String? detail;

  /// An optional button under the message, such as "Hear me".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = SpeakColors.of(context);
    final theme = Theme.of(context);
    final (icon, fg, bg) = switch (kind) {
      FeedbackKind.success => (Icons.check_circle_rounded, colors.success, colors.successSoft),
      FeedbackKind.nearly => (Icons.thumb_up_alt_rounded, colors.nearly, colors.nearlySoft),
      FeedbackKind.info => (Icons.lightbulb_rounded, colors.calm, colors.calmSoft),
    };
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey('$kind$message$detail'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: fg, width: colors.cardBorderWidth > 2 ? 3 : 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface)),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(detail!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface)),
                    ],
                    if (action != null) ...[const SizedBox(height: 4), action!],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

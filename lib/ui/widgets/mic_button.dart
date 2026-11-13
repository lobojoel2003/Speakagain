import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

enum MicState { ready, listening, checking }

/// The big round microphone button, centred within thumb reach. While
/// listening, a soft ring grows with the voice so the person can see they are
/// being heard.
class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.state,
    required this.level,
    required this.onPressed,
    required this.label,
    this.size = 128,
  });

  final MicState state;
  final ValueListenable<double> level;
  final VoidCallback? onPressed;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = SpeakColors.of(context);
    final listening = state == MicState.listening;
    final color = listening ? colors.success : scheme.primary;
    final onColor = listening ? colors.onSuccess : scheme.onPrimary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size + 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (listening)
                  ValueListenableBuilder<double>(
                    valueListenable: level,
                    builder: (context, value, _) {
                      final grow = reduceMotion ? 0.5 : value;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        width: size + 8 + 36 * grow,
                        height: size + 8 + 36 * grow,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.22)),
                      );
                    },
                  ),
                Material(
                  color: color,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: color.withValues(alpha: 0.4),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPressed,
                    child: SizedBox.square(
                      dimension: size,
                      child: Center(
                        child: state == MicState.checking
                            ? SizedBox.square(
                                dimension: size * 0.4,
                                child: CircularProgressIndicator(strokeWidth: 6, color: onColor),
                              )
                            : Icon(
                                listening ? Icons.stop_rounded : Icons.mic_rounded,
                                size: size * 0.5,
                                color: onColor,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The label is part of the target too: easier to hit with an unsteady hand.
          GestureDetector(
            onTap: onPressed,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(label, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

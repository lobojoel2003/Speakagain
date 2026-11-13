import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/pack.dart';
import '../../services/pack_repository.dart';
import '../theme.dart';

/// A pack item's picture: an OpenMoji symbol or an image from the pack.
class PackImage extends StatefulWidget {
  const PackImage({super.key, required this.pack, required this.reference, this.size = 200, this.semanticLabel});

  final Pack pack;
  final String reference;
  final double size;
  final String? semanticLabel;

  @override
  State<PackImage> createState() => _PackImageState();
}

class _PackImageState extends State<PackImage> {
  Future<Uint8List?>? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bytes ??= context.read<AppState>().packs.image(widget.pack, widget.reference);
  }

  @override
  void didUpdateWidget(PackImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference || oldWidget.pack.id != widget.pack.id) {
      _bytes = context.read<AppState>().packs.image(widget.pack, widget.reference);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox.square(dimension: widget.size);
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      excludeSemantics: true,
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return placeholder;
          final isSvg = widget.reference.startsWith('openmoji:') || widget.reference.endsWith('.svg');
          return SizedBox.square(
            dimension: widget.size,
            child: isSvg
                ? SvgPicture.memory(bytes, fit: BoxFit.contain)
                : Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
          );
        },
      ),
    );
  }
}

/// An OpenMoji symbol bundled with the app, by code (such as `1F31F`).
class Symbol extends StatelessWidget {
  const Symbol(this.code, {super.key, this.size = 56});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(PackRepository.openMojiAsset('openmoji:$code'), width: size, height: size),
  );
}

/// A large rounded card with a soft border, used for menus and choices.
class SpeakCard extends StatelessWidget {
  const SpeakCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.padding = const EdgeInsets.all(20),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = SpeakColors.of(context);
    final radius = BorderRadius.circular(26);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: color ?? colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor ?? colors.cardBorder, width: borderWidth ?? colors.cardBorderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Spacing that grows with the screen, so phones and tablets both feel calm.
EdgeInsets pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final side = width > 900 ? (width - 760) / 2 : (width > 600 ? 40.0 : 20.0);
  return EdgeInsets.fromLTRB(side, 12, side, 24);
}

/// Keeps content to a comfortable reading width on tablets and the web.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// A full-width button with an icon above or beside a short label: icons help
/// people who find reading hard.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.color,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 32),
        const SizedBox(width: 14),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 76)),
      backgroundColor: color == null ? null : WidgetStatePropertyAll(color),
      foregroundColor: foreground == null ? null : WidgetStatePropertyAll(foreground),
    );
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: content)
        : OutlinedButton(onPressed: onPressed, style: style, child: content);
  }
}

/// A secondary action shown as a large icon with a word under it, for the row
/// of helpers (hint, hear it, skip) within thumb reach.
class HelperButton extends StatelessWidget {
  const HelperButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = SpeakColors.of(context);
    final enabled = onPressed != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: highlight ? colors.calmSoft : colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: highlight ? colors.calm : colors.cardBorder,
                width: highlight ? 2.5 : colors.cardBorderWidth,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Opacity(
                opacity: enabled ? 1 : 0.4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 34, color: highlight ? colors.calm : scheme.onSurface),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short instruction with a speaker button that reads it out loud.
class SpokenInstruction extends StatelessWidget {
  const SpokenInstruction({super.key, required this.text, required this.onSpeak});

  final String text;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      ),
      const SizedBox(width: 4),
      IconButton(onPressed: onSpeak, tooltip: text, icon: const Icon(Icons.volume_up_rounded)),
    ],
  );
}

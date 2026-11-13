import 'package:flutter/material.dart';

/// Colours with a meaning beyond Material's scheme. There is deliberately no
/// red anywhere: a wrong answer is never shown as an error.
@immutable
class SpeakColors extends ThemeExtension<SpeakColors> {
  const SpeakColors({
    required this.success,
    required this.onSuccess,
    required this.successSoft,
    required this.nearly,
    required this.nearlySoft,
    required this.calm,
    required this.calmSoft,
    required this.card,
    required this.cardBorder,
    required this.cardBorderWidth,
  });

  final Color success;
  final Color onSuccess;
  final Color successSoft;

  /// For "nearly" and "let's try again": warm, never alarming.
  final Color nearly;
  final Color nearlySoft;

  /// For hints and information.
  final Color calm;
  final Color calmSoft;
  final Color card;
  final Color cardBorder;
  final double cardBorderWidth;

  static SpeakColors of(BuildContext context) => Theme.of(context).extension<SpeakColors>()!;

  @override
  SpeakColors copyWith() => this;

  @override
  SpeakColors lerp(SpeakColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

enum SpeakThemeKind { light, dark, contrast }

const _fontFamily = 'Atkinson Hyperlegible';

/// Calm, high-contrast themes with large text and large touch targets.
///
/// Text sizes start large (body 22, words 56) because many people with aphasia
/// also have trouble reading; every colour pair meets WCAG AAA (7:1) for text.
ThemeData buildTheme(SpeakThemeKind kind) {
  final (scheme, colors) = switch (kind) {
    SpeakThemeKind.light => (
      const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF17507A),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFD9E8F5),
        onPrimaryContainer: Color(0xFF0B2E4A),
        secondary: Color(0xFF0E5C55),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFD4EDE8),
        onSecondaryContainer: Color(0xFF06302C),
        tertiary: Color(0xFF6A4A00),
        onTertiary: Color(0xFFFFFFFF),
        error: Color(0xFF6A4A00),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFFF7F4EE),
        onSurface: Color(0xFF16202A),
        onSurfaceVariant: Color(0xFF3A4652),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFFFFFFF),
        surfaceContainer: Color(0xFFF0ECE4),
        surfaceContainerHigh: Color(0xFFEAE5DB),
        surfaceContainerHighest: Color(0xFFE3DED3),
        outline: Color(0xFF6B7682),
        outlineVariant: Color(0xFFCFC9BE),
      ),
      const SpeakColors(
        success: Color(0xFF1F6B3A),
        onSuccess: Color(0xFFFFFFFF),
        successSoft: Color(0xFFDDF1E3),
        nearly: Color(0xFF6A4A00),
        nearlySoft: Color(0xFFFCEFCF),
        calm: Color(0xFF17507A),
        calmSoft: Color(0xFFE3EEF7),
        card: Color(0xFFFFFFFF),
        cardBorder: Color(0xFFDCD6CA),
        cardBorderWidth: 1.5,
      ),
    ),
    SpeakThemeKind.dark => (
      const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF9DCBF2),
        onPrimary: Color(0xFF0A2338),
        primaryContainer: Color(0xFF1C3D5A),
        onPrimaryContainer: Color(0xFFD9E8F5),
        secondary: Color(0xFF8FD8CC),
        onSecondary: Color(0xFF05302A),
        secondaryContainer: Color(0xFF15433D),
        onSecondaryContainer: Color(0xFFD4EDE8),
        tertiary: Color(0xFFF2CC7A),
        onTertiary: Color(0xFF2F2100),
        error: Color(0xFFF2CC7A),
        onError: Color(0xFF2F2100),
        surface: Color(0xFF11171E),
        onSurface: Color(0xFFF1EEE8),
        onSurfaceVariant: Color(0xFFC4CCD4),
        surfaceContainerLowest: Color(0xFF0C1116),
        surfaceContainerLow: Color(0xFF19212A),
        surfaceContainer: Color(0xFF1D2630),
        surfaceContainerHigh: Color(0xFF232D38),
        surfaceContainerHighest: Color(0xFF2A3541),
        outline: Color(0xFF8A96A2),
        outlineVariant: Color(0xFF34404C),
      ),
      const SpeakColors(
        success: Color(0xFF8EDDA6),
        onSuccess: Color(0xFF07301A),
        successSoft: Color(0xFF173A26),
        nearly: Color(0xFFF2CC7A),
        nearlySoft: Color(0xFF3A2E12),
        calm: Color(0xFF9DCBF2),
        calmSoft: Color(0xFF1A2E40),
        card: Color(0xFF19212A),
        cardBorder: Color(0xFF2E3A46),
        cardBorderWidth: 1.5,
      ),
    ),
    SpeakThemeKind.contrast => (
      const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFE14D),
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFF000000),
        onPrimaryContainer: Color(0xFFFFE14D),
        secondary: Color(0xFF7DF9FF),
        onSecondary: Color(0xFF000000),
        secondaryContainer: Color(0xFF000000),
        onSecondaryContainer: Color(0xFF7DF9FF),
        tertiary: Color(0xFFFFE14D),
        onTertiary: Color(0xFF000000),
        error: Color(0xFFFFE14D),
        onError: Color(0xFF000000),
        surface: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFFFFFFF),
        surfaceContainerLowest: Color(0xFF000000),
        surfaceContainerLow: Color(0xFF000000),
        surfaceContainer: Color(0xFF000000),
        surfaceContainerHigh: Color(0xFF000000),
        surfaceContainerHighest: Color(0xFF000000),
        outline: Color(0xFFFFFFFF),
        outlineVariant: Color(0xFFFFFFFF),
      ),
      const SpeakColors(
        success: Color(0xFF7DFF9B),
        onSuccess: Color(0xFF000000),
        successSoft: Color(0xFF000000),
        nearly: Color(0xFFFFE14D),
        nearlySoft: Color(0xFF000000),
        calm: Color(0xFF7DF9FF),
        calmSoft: Color(0xFF000000),
        card: Color(0xFF000000),
        cardBorder: Color(0xFFFFFFFF),
        cardBorderWidth: 3,
      ),
    ),
  };

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: _fontFamily);
  final text = base.textTheme
      .copyWith(
        displayLarge: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, height: 1.1),
        displayMedium: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, height: 1.12),
        displaySmall: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, height: 1.15),
        headlineLarge: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.2),
        headlineMedium: const TextStyle(fontSize: 31, fontWeight: FontWeight.w700, height: 1.22),
        headlineSmall: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, height: 1.25),
        titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
        titleMedium: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.3),
        titleSmall: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3),
        bodyLarge: const TextStyle(fontSize: 22, height: 1.4),
        bodyMedium: const TextStyle(fontSize: 20, height: 1.4),
        bodySmall: const TextStyle(fontSize: 18, height: 1.4),
        labelLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
        labelMedium: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.2),
        labelSmall: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface, fontFamily: _fontFamily);

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
  final contrastSide = kind == SpeakThemeKind.contrast
      ? const BorderSide(color: Colors.white, width: 3)
      : BorderSide.none;

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [colors],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 72,
      titleTextStyle: text.headlineSmall,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 72),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: buttonShape,
        side: contrastSide,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 72),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: buttonShape,
        foregroundColor: scheme.onSurface,
        side: BorderSide(
          color: kind == SpeakThemeKind.contrast ? Colors.white : scheme.outline,
          width: kind == SpeakThemeKind.contrast ? 3 : 2,
        ),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: buttonShape,
        textStyle: text.labelMedium,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(64, 64), iconSize: 32)),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      trackOutlineWidth: const WidgetStatePropertyAll(2),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      iconColor: scheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 84,
      backgroundColor: kind == SpeakThemeKind.light ? const Color(0xFFFFFFFF) : scheme.surfaceContainerLow,
      indicatorColor: kind == SpeakThemeKind.contrast ? scheme.primary : scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 32,
          color: states.contains(WidgetState.selected) && kind == SpeakThemeKind.contrast
              ? Colors.black
              : scheme.onSurface,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kind == SpeakThemeKind.light ? Colors.white : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: contrastSide),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: text.bodyLarge?.copyWith(color: scheme.surface),
      backgroundColor: scheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1.5, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 60)),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
        side: WidgetStatePropertyAll(
          BorderSide(color: kind == SpeakThemeKind.contrast ? Colors.white : scheme.outline, width: 2),
        ),
      ),
    ),
  );
}

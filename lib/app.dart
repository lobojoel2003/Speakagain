import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'core/languages.dart';
import 'l10n/app_localizations.dart';
import 'models/settings.dart';
import 'ui/screens/root_screen.dart';
import 'ui/theme.dart';

class SpeakagainApp extends StatelessWidget {
  const SpeakagainApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: state,
    child: Consumer<AppState>(
      builder: (context, app, _) {
        final settings = app.settings;
        final (light, dark) = switch (settings.theme) {
          ThemeChoice.system => (SpeakThemeKind.light, SpeakThemeKind.dark),
          ThemeChoice.light => (SpeakThemeKind.light, SpeakThemeKind.light),
          ThemeChoice.dark => (SpeakThemeKind.dark, SpeakThemeKind.dark),
          ThemeChoice.contrast => (SpeakThemeKind.contrast, SpeakThemeKind.contrast),
        };
        return MaterialApp(
          title: 'Speakagain',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(light),
          darkTheme: buildTheme(dark),
          themeMode: settings.theme == ThemeChoice.system ? ThemeMode.system : ThemeMode.light,
          locale: settings.language == null ? null : app.language.locale,
          supportedLocales: [for (final l in appLanguages) l.locale],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supported) => languageForLocale(locale).locale,
          builder: (context, child) {
            // The person's text size choice on top of the phone's, within limits
            // that keep every screen usable.
            final media = MediaQuery.of(context);
            final system = media.textScaler.scale(1);
            final scale = (system * settings.textSize.scale).clamp(1.0, 2.0);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
          home: const RootScreen(),
        );
      },
    ),
  );
}

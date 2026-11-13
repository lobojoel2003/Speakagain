import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

/// First start: language, a sound check, speech checking, and go.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _heard = false;

  void _next() => setState(() => _step++);

  Future<void> _finish() async {
    final app = context.read<AppState>();
    await app.updateSettings(app.settings.copyWith(onboarded: true));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget page({required Widget top, required List<Widget> actions}) => SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: pagePadding(context),
              child: ReadableWidth(child: top),
            ),
          ),
          ReadableWidth(
            maxWidth: 640,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ),
        ],
      ),
    );

    final body = switch (_step) {
      0 => page(
        top: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/brand/icon.png', width: 104, height: 104),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.welcomeTitle, style: theme.textTheme.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.welcomeBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Text(l.chooseLanguage, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            SpeakCard(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LanguageList(
                shrinkWrap: true,
                current: app.language.code,
                onSelected: (code) => app.updateSettings(app.settings.copyWith(language: code)),
              ),
            ),
          ],
        ),
        actions: [BigButton(icon: Icons.arrow_forward_rounded, label: l.continueButton, onPressed: _next)],
      ),
      1 => page(
        top: Column(
          children: [
            const SizedBox(height: 32),
            Text(l.voiceCheckTitle, style: theme.textTheme.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.voiceCheckBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Semantics(
              button: true,
              label: l.voiceCheckSample,
              child: Material(
                color: theme.colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    await app.speech.speak(l.voiceCheckSample);
                    if (mounted) setState(() => _heard = true);
                  },
                  child: SizedBox.square(
                    dimension: 150,
                    child: Icon(Icons.volume_up_rounded, size: 80, color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_heard) Text(l.turnUpVolume, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
        actions: [BigButton(icon: Icons.check_rounded, label: l.yesICanHear, onPressed: _next)],
      ),
      2 => _speechStep(context, page),
      _ => page(
        top: Column(
          children: [
            const SizedBox(height: 40),
            const Symbol('1F331', size: 140),
            const SizedBox(height: 16),
            Text(l.readyTitle, style: theme.textTheme.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.readyBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
        actions: [BigButton(icon: Icons.play_arrow_rounded, label: l.startButton, onPressed: _finish)],
      ),
    };
    return Scaffold(body: body);
  }

  Widget _speechStep(BuildContext context, Widget Function({required Widget top, required List<Widget> actions}) page) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final model = app.catalog.recognizer(app.settings.recognizer);
    final state = app.downloadState(model);
    final installed = app.isInstalled(model);
    final supported = app.models.isSupported;

    return page(
      top: Column(
        children: [
          const SizedBox(height: 32),
          const Symbol('1F5E3', size: 120),
          const SizedBox(height: 16),
          Text(l.speechSetupTitle, style: theme.textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            supported ? l.speechSetupBody : l.speechSetupWeb,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (supported) ...[
            const SizedBox(height: 16),
            Text(l.speechSetupWifi, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (state.active) ...[
              LinearProgressIndicator(value: state.progress, minHeight: 12),
              const SizedBox(height: 8),
              Text(l.downloading(((state.progress ?? 0) * 100).round()), style: theme.textTheme.titleMedium),
            ] else if (installed)
              Text(l.installed, style: theme.textTheme.titleLarge)
            else if (state.failed)
              Text(l.downloadFailed, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
        ],
      ),
      actions: [
        if (supported && !installed && !state.active) ...[
          BigButton(
            icon: Icons.download_rounded,
            label: l.speechSetupDownload(formatBytes(model.totalBytes)),
            onPressed: () {
              app.download(model);
              app.speech.ensureMicrophone();
            },
          ),
          const SizedBox(height: 12),
          BigButton(icon: Icons.arrow_forward_rounded, label: l.speechSetupLater, filled: false, onPressed: _next),
        ] else
          BigButton(icon: Icons.arrow_forward_rounded, label: l.continueButton, onPressed: _next),
      ],
    );
  }
}

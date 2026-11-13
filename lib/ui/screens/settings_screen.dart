import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/answer_matcher.dart';
import '../../core/languages.dart';
import '../../l10n/app_localizations.dart';
import '../../models/settings.dart';
import '../../services/models/model_catalog.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'packs_screen.dart';

String formatBytes(int bytes) => bytes >= 1000000 ? '${(bytes / 1000000).round()} MB' : '${(bytes / 1000).round()} kB';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Future<void> set(AppSettings next) => app.updateSettings(next);

    final voiceName = s.voiceId == systemVoiceId ? l.phoneVoice : (app.catalog.voice(s.voiceId)?.name ?? l.phoneVoice);

    return SafeArea(
      child: ListView(
        padding: pagePadding(context),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(l.settingsTitle, style: theme.textTheme.headlineLarge),
                const SizedBox(height: 12),
                _Section(l.sectionLanguage, [
                  ListTile(
                    leading: const Icon(Icons.language_rounded, size: 32),
                    title: Text(app.language.nativeName),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                    onTap: () async {
                      final code = await showLanguagePicker(context, app.language.code);
                      if (code != null) await set(s.copyWith(language: code));
                    },
                  ),
                ]),
                _Section(l.sectionVoice, [
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_rounded, size: 32),
                    title: Text(voiceName),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VoiceScreen())),
                  ),
                  _ChoiceRow<SpeechSpeed>(
                    title: l.voiceSpeed,
                    value: s.speechSpeed,
                    options: {SpeechSpeed.slower: l.speedSlower, SpeechSpeed.normal: l.speedNormal},
                    onChanged: (v) => set(s.copyWith(speechSpeed: v)),
                  ),
                ]),
                _Section(l.sectionSpeech, [
                  ListTile(
                    leading: const Icon(Icons.mic_rounded, size: 32),
                    title: Text(l.speechChecking),
                    subtitle: Text(app.models.isSupported ? l.speechCheckingHint : l.speechSetupWeb),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                    onTap: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const SpeechCheckingScreen())),
                  ),
                ]),
                _Section(l.sectionPractice, [
                  _ChoiceRow<int>(
                    title: l.sessionLength,
                    value: s.sessionLength,
                    options: {for (final n in AppSettings.sessionLengths) n: '$n'},
                    onChanged: (v) => set(s.copyWith(sessionLength: v)),
                  ),
                  _ChoiceRow<int>(
                    title: l.pictureChoices,
                    value: s.pictureChoices,
                    options: {for (final n in AppSettings.pictureChoiceCounts) n: '$n'},
                    onChanged: (v) => set(s.copyWith(pictureChoices: v)),
                  ),
                  SwitchListTile(
                    title: Text(l.autoHints),
                    value: s.autoHints,
                    onChanged: (v) => set(s.copyWith(autoHints: v)),
                  ),
                  SwitchListTile(
                    title: Text(l.speakInstructions),
                    value: s.speakInstructions,
                    onChanged: (v) => set(s.copyWith(speakInstructions: v)),
                  ),
                  SwitchListTile(
                    title: Text(l.sounds),
                    value: s.sounds,
                    onChanged: (v) => set(s.copyWith(sounds: v)),
                  ),
                ]),
                _Section(l.sectionDisplay, [
                  _ChoiceRow<TextSizeChoice>(
                    title: l.textSize,
                    value: s.textSize,
                    options: {
                      TextSizeChoice.large: l.textLarge,
                      TextSizeChoice.larger: l.textLarger,
                      TextSizeChoice.largest: l.textLargest,
                    },
                    onChanged: (v) => set(s.copyWith(textSize: v)),
                  ),
                  _ChoiceRow<ThemeChoice>(
                    title: l.theme,
                    value: s.theme,
                    vertical: true,
                    options: {
                      ThemeChoice.system: l.themeSystem,
                      ThemeChoice.light: l.themeLight,
                      ThemeChoice.dark: l.themeDark,
                      ThemeChoice.contrast: l.themeContrast,
                    },
                    onChanged: (v) => set(s.copyWith(theme: v)),
                  ),
                ]),
                _Section(l.sectionPacks, [
                  ListTile(
                    leading: const Icon(Icons.collections_bookmark_rounded, size: 32),
                    title: Text(l.sectionPacks),
                    subtitle: Text(l.packsHint),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PacksScreen())),
                  ),
                ]),
                _Section(l.sectionAbout, [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, size: 32),
                    title: Text(l.aboutApp),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded, size: 32),
                    title: Text(l.resetProgress),
                    onTap: () async {
                      final ok = await confirm(context, l.resetConfirm, l.resetProgress);
                      if (ok) await app.resetProgress();
                    },
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String message, String action) async {
  final l = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

/// Lists every language by its own name, so nobody has to read English to find theirs.
Future<String?> showLanguagePicker(BuildContext context, String current) => showDialog<String>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
      child: LanguageList(current: current, onSelected: (code) => Navigator.pop(context, code)),
    ),
  ),
);

class LanguageList extends StatelessWidget {
  const LanguageList({super.key, required this.current, required this.onSelected, this.shrinkWrap = false});

  final String current;
  final ValueChanged<String> onSelected;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        for (final language in appLanguages)
          ListTile(
            selected: language.code == current,
            selectedTileColor: theme.colorScheme.primaryContainer,
            selectedColor: theme.colorScheme.onPrimaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              language.nativeName,
              style: theme.textTheme.headlineSmall,
              textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
            subtitle: language.nativeName == language.englishName ? null : Text(language.englishName),
            trailing: language.code == current ? const Icon(Icons.check_circle_rounded, size: 32) : null,
            onTap: () => onSelected(language.code),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        ),
        SpeakCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: children),
        ),
      ],
    ),
  );
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.vertical = false,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (vertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            RadioGroup<T>(
              groupValue: value,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              child: Column(
                children: [
                  for (final entry in options.entries)
                    RadioListTile<T>(
                      value: entry.key,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value, style: theme.textTheme.bodyLarge),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final entry in options.entries) ButtonSegment<T>(value: entry.key, label: Text(entry.value)),
              ],
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// Download button with progress, used for speech models and voices.
class DownloadTile extends StatelessWidget {
  const DownloadTile({
    super.key,
    required this.item,
    required this.title,
    required this.subtitle,
    required this.onDownload,
    this.selected = false,
    this.onSelect,
    this.extraBytes = 0,
  });

  final Downloadable item;
  final String title;
  final String subtitle;
  final Future<void> Function() onDownload;
  final bool selected;
  final VoidCallback? onSelect;

  /// Bytes also needed (the shared voice data) the first time.
  final int extraBytes;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = app.downloadState(item);
    final installed = app.isInstalled(item);
    Widget trailing;
    if (state.active) {
      trailing = SizedBox(
        width: 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: state.progress, minHeight: 8),
            const SizedBox(height: 6),
            Text(l.downloading(((state.progress ?? 0) * 100).round()), style: theme.textTheme.labelSmall),
          ],
        ),
      );
    } else if (installed) {
      trailing = selected
          ? Chip(label: Text(l.inUse), avatar: const Icon(Icons.check_rounded))
          : (onSelect == null ? Chip(label: Text(l.installed)) : FilledButton(onPressed: onSelect, child: Text(l.use)));
    } else {
      trailing = OutlinedButton(onPressed: onDownload, child: Text(formatBytes(item.totalBytes + extraBytes)));
    }
    return Column(
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text(state.failed ? l.downloadFailed : subtitle),
          trailing: trailing,
          onTap: installed && onSelect != null && !selected ? onSelect : null,
        ),
        if (installed && !state.active)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l.remove),
                onPressed: () async {
                  if (await confirm(context, '${l.remove}: $title?', l.remove)) await app.removeModel(item);
                },
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> installModelsFromFiles(BuildContext context) async {
  final app = context.read<AppState>();
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final files = await FilePicker.pickFiles();
  final paths = [
    for (final f in files)
      if (f.path != null) f.path!,
  ];
  if (paths.isEmpty) return;
  try {
    final count = await app.installFromFiles(paths);
    messenger.showSnackBar(SnackBar(content: Text(l.installedFromFile(count))));
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

class VoiceScreen extends StatelessWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final voices = app.catalog.voicesFor(app.language.code);
    final data = app.catalog.voiceData;
    final needsData = data != null && !app.isInstalled(data);
    final s = app.settings;

    return Scaffold(
      appBar: AppBar(title: Text(l.sectionVoice)),
      body: ListView(
        padding: pagePadding(context),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpeakCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: RadioGroup<String>(
                    groupValue: s.voiceId,
                    onChanged: (v) {
                      if (v != null) app.updateSettings(s.copyWith(voiceId: v));
                    },
                    child: RadioListTile<String>(
                      value: systemVoiceId,
                      title: Text(l.phoneVoice),
                      subtitle: Text(l.phoneVoiceHint),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.naturalVoices, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(app.models.isSupported ? l.naturalVoicesHint : l.notOnWeb, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                if (app.models.isSupported)
                  for (final voice in voices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SpeakCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DownloadTile(
                          item: voice,
                          title: voice.name,
                          subtitle:
                              '${voice.gender == 'female' ? l.female : l.male} · ${voice.locale} · ${l.voiceLicence(voice.license)}',
                          selected: s.voiceId == voice.id,
                          extraBytes: needsData ? data.totalBytes : 0,
                          onSelect: () => app.updateSettings(s.copyWith(voiceId: voice.id)),
                          onDownload: () async {
                            await app.downloadVoice(voice);
                          },
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                BigButton(
                  icon: Icons.volume_up_rounded,
                  label: l.testVoice,
                  filled: false,
                  onPressed: () => app.speech.speak(l.voiceCheckSample),
                ),
                if (app.models.isSupported) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(l.installFromFile),
                    onPressed: () => installModelsFromFiles(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpeechCheckingScreen extends StatelessWidget {
  const SpeechCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = app.settings;

    return Scaffold(
      appBar: AppBar(title: Text(l.sectionSpeech)),
      body: ListView(
        padding: pagePadding(context),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!app.models.isSupported)
                  SpeakCard(child: Text(l.speechSetupWeb, style: theme.textTheme.bodyLarge))
                else ...[
                  SpeakCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SwitchListTile(
                      title: Text(l.speechChecking),
                      subtitle: Text(l.speechCheckingHint),
                      value: s.speechChecking,
                      onChanged: (v) => app.updateSettings(s.copyWith(speechChecking: v)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final model in app.catalog.recognizers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SpeakCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DownloadTile(
                          item: model,
                          title: model.size == RecognizerSize.standard ? l.speechModelStandard : l.speechModelSmall,
                          subtitle: model.size == RecognizerSize.standard
                              ? l.speechModelStandardHint
                              : l.speechModelSmallHint,
                          selected: s.recognizer == model.size,
                          onSelect: () => app.updateSettings(s.copyWith(recognizer: model.size)),
                          onDownload: () async {
                            if (await app.download(model)) {
                              await app.updateSettings(
                                app.settings.copyWith(recognizer: model.size, speechChecking: true),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(l.speechSetupWifi, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  SpeakCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.strictness, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<Strictness>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(value: Strictness.gentle, label: Text(l.strictnessGentle)),
                                ButtonSegment(value: Strictness.close, label: Text(l.strictnessClose)),
                              ],
                              selected: {s.strictness},
                              onSelectionChanged: (v) => app.updateSettings(s.copyWith(strictness: v.first)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(l.installFromFile),
                    onPressed: () => installModelsFromFiles(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

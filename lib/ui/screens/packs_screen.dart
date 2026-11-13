import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../core/build_info.dart';
import '../../l10n/app_localizations.dart';
import '../../models/pack.dart';
import '../exercise_info.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

/// The packs in the chosen language, and adding packs others have made.
class PacksScreen extends StatelessWidget {
  const PacksScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final app = context.read<AppState>();
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['zip', 'json']);
    if (file == null) return;
    try {
      final pack = await app.importPack(await file.readAsBytes());
      final sameLanguage = pack.language.split('-').first == app.language.code;
      messenger.showSnackBar(SnackBar(content: Text(sameLanguage ? l.packAdded(pack.title) : l.packOtherLanguage)));
    } on PackFormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('${l.packNotAdded}\n${e.problems.take(3).join('\n')}'),
        ),
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.packNotAdded)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SpeakColors.of(context);
    final packs = app.currentPacks;

    return Scaffold(
      appBar: AppBar(title: Text(l.sectionPacks)),
      body: ListView(
        padding: pagePadding(context),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.packsHint, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                for (final pack in packs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SpeakCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (pack.items.firstWhere((i) => i.hasImage, orElse: () => pack.items.first).image
                                  case final image?)
                                Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: PackImage(pack: pack, reference: image, size: 56),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pack.title, style: theme.textTheme.titleLarge),
                                    Text(l.packItems(pack.items.length), style: theme.textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                              if (pack.source == PackSource.imported)
                                IconButton(
                                  tooltip: l.removePack,
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () async {
                                    if (await confirm(context, l.removePackConfirm(pack.title), l.removePack)) {
                                      await app.removePack(pack);
                                    }
                                  },
                                ),
                            ],
                          ),
                          if (pack.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(pack.description, style: theme.textTheme.bodyMedium),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final type in pack.exercises)
                                Chip(
                                  avatar: Symbol(type.symbol, size: 26),
                                  label: Text(type.title(l)),
                                  backgroundColor: colors.calmSoft,
                                  side: BorderSide.none,
                                ),
                            ],
                          ),
                          if (pack.author.isNotEmpty || pack.license.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              [pack.author, pack.license].where((s) => s.isNotEmpty).join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                BigButton(icon: Icons.add_rounded, label: l.addPack, onPressed: () => _add(context)),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l.makePacks),
                  onPressed: () => launchUrl(Uri.parse(BuildInfo.packGuideUrl), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

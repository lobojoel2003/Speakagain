import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/build_info.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget block(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SpeakCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.aboutApp)),
      body: ListView(
        padding: pagePadding(context),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/brand/icon.png', width: 112, height: 112, semanticLabel: l.appTitle),
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text(l.appTitle, style: theme.textTheme.headlineLarge)),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    if (info == null) return const SizedBox(height: 28);
                    final details = BuildInfo.details;
                    return Center(
                      child: Text(
                        '${l.version(info.version, info.buildNumber)}${details.isEmpty ? '' : '\n$details'}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                block(l.aboutApp, l.aboutBody),
                block(l.privacy, l.privacyBody),
                block(l.credits, l.creditsBody),
                BigButton(
                  icon: Icons.code_rounded,
                  label: l.sourceCode,
                  filled: false,
                  onPressed: () => launchUrl(Uri.parse(BuildInfo.repositoryUrl), mode: LaunchMode.externalApplication),
                ),
                const SizedBox(height: 12),
                BigButton(
                  icon: Icons.description_outlined,
                  label: l.licences,
                  filled: false,
                  onPressed: () => showLicensePage(context: context, applicationName: l.appTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

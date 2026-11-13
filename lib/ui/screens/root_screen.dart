import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// Onboarding on first start, then Home, Progress and Settings, switched with
/// a bottom bar that is easy to reach with one thumb.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.settings.onboarded) return const OnboardingScreen();
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [HomeScreen(), ProgressScreen(), SettingsScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: l.navProgress,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}

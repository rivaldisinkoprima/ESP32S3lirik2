import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'ble_sync_screen.dart';
import 'settings_screen.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<Widget> _buildScreens(Locale locale) => [
    HomeScreen(key: ValueKey('home_${locale.languageCode}')),
    BleSyncScreen(key: ValueKey('sync_${locale.languageCode}')),
    SettingsScreen(key: ValueKey('settings_${locale.languageCode}')),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleProvider>().locale;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        key: ValueKey('stack_${locale.languageCode}'),
        children: _buildScreens(locale),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.home),
            selectedIcon: const Icon(LucideIcons.home),
            label: l10n?.translate('homeTitle') ?? 'Home',
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.bluetooth),
            selectedIcon: const Icon(LucideIcons.bluetooth),
            label: l10n?.translate('syncTitle') ?? 'Sync',
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.settings),
            selectedIcon: const Icon(LucideIcons.settings),
            label: l10n?.translate('settingsTitle') ?? 'Settings',
          ),
        ],
      ),
    );
  }
}

import 'package:lucide_icons/lucide_icons.dart';
// Settings Screen
//
// Routes: '/settings'

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/ble_provider.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final int _defaultValue = 150;

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final offset = workspace.globalOffsetMs;
    final isPositive = offset >= 0;
    final isDefault = offset == _defaultValue;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Image.asset('assets/logo1.png'),
        ),
        title: Text(AppLocalizations.of(context)?.translate('settingsTitle') ?? 'Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context)?.translate('delayOffset') ?? 'DELAY OFFSET',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.translate('hardwareDelayOffset') ?? 'Hardware Delay Offset',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey<int>(offset),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        ),
                        child: Text(
                          '${isPositive ? '+' : ''}$offset ms',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isPositive
                                ? Theme.of(context).colorScheme.onSecondaryContainer
                                : Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.translate('hardwareDelayDesc') ?? 'Digunakan untuk kompensasi delay DFPlayer',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.translate('slower') ?? 'Lebih lambat',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade400,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.translate('faster') ?? 'Lebih cepat',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24,
                    ),
                    activeTrackColor: isPositive ? Colors.green : Colors.red,
                    inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    thumbColor: isPositive ? Colors.green : Colors.red,
                    overlayColor: (isPositive ? Colors.green : Colors.red)
                        .withAlpha(32),
                    valueIndicatorColor: Theme.of(context).colorScheme.primary,
                    valueIndicatorTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  child: Slider(
                    value: offset.toDouble(),
                    min: -500,
                    max: 500,
                    divisions: 100,
                    label: '${isPositive ? '+' : ''}$offset ms',
                    onChanged: (double value) {
                      workspace.setGlobalOffset(value.toInt());
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '-500ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '+500ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)?.translate('quickValues') ?? 'Nilai Cepat',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [-200, -100, 0, 100, 150, 200, 300].map((val) {
                    final isSelected = offset == val;
                    return ChoiceChip(
                      label: Text('${val > 0 ? '+' : ''}$val'),
                      selected: isSelected,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      selectedColor: val >= 0
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                      onSelected: (_) {
                        HapticFeedback.lightImpact();
                        workspace.setGlobalOffset(val);
                      },
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (val >= 0
                                  ? Theme.of(context).colorScheme.onSecondaryContainer
                                  : Theme.of(context).colorScheme.onErrorContainer)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                           color: isSelected ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant,
                        )
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)?.translate('explanation') ?? 'Penjelasan',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: LucideIcons.arrowRight,
                  color: Colors.green,
                  title: AppLocalizations.of(context)?.translate('positiveOffset') ?? 'Offset Positif (+)',
                  desc:
                      AppLocalizations.of(context)?.translate('positiveOffsetDesc') ?? 'Lirik diputar lebih awal dari audio. Gunakan jika lirik terlambat.',
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  icon: LucideIcons.arrowLeft,
                  color: Colors.red,
                  title: AppLocalizations.of(context)?.translate('negativeOffset') ?? 'Offset Negatif (-)',
                  desc:
                      AppLocalizations.of(context)?.translate('negativeOffsetDesc') ?? 'Lirik diputar lebih lambat dari audio. Gunakan jika lirik terlalu cepat.',
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDefault
                            ? null
                            : () {
                                workspace.setGlobalOffset(_defaultValue);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(context)?.translate('offsetResetTo', ['$_defaultValue']) ?? 'Offset dikembalikan ke $_defaultValue ms',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                        icon: const Icon(LucideIcons.history, size: 18),
                        label: Text(AppLocalizations.of(context)?.translate('reset') ?? 'Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context)?.translate('appearance') ?? 'APPEARANCE',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return SwitchListTile(
                title: Text(AppLocalizations.of(context)?.translate('darkMode') ?? 'Dark Mode'),
                subtitle: Text(
                  themeProvider.isDarkMode
                      ? (AppLocalizations.of(context)?.translate('darkModeEnabled') ?? 'Dark theme enabled')
                      : (AppLocalizations.of(context)?.translate('darkModeDisabled') ?? 'Light theme enabled'),
                ),
                secondary: Icon(
                  themeProvider.isDarkMode ? LucideIcons.moon : LucideIcons.sun,
                  size: 28,
                ),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  themeProvider.setDarkMode(value);
                },
              );
            },
          ),
          const Divider(height: 32),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context)?.translate('languageCaps') ?? 'LANGUAGE',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, _) {
              final l10n = AppLocalizations.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(

                    leading: const Icon(LucideIcons.globe, size: 28),
                    title: Text(l10n?.translate('language') ?? 'Language'),
                    subtitle: Text(
                      localeProvider.locale.languageCode == 'en'
                          ? (l10n?.translate('english') ?? 'English')
                          : (l10n?.translate('indonesian') ?? 'Bahasa Indonesia'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                                value: 'en',
                                label: Text('EN', style: TextStyle(fontWeight: FontWeight.bold))),
                            ButtonSegment<String>(
                                value: 'id',
                                label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          selected: {localeProvider.locale.languageCode},
                          onSelectionChanged: (Set<String> newSelection) {
                            HapticFeedback.lightImpact();
                            localeProvider.setLocale(Locale(newSelection.first));
                          },
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            )
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

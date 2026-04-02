// Settings Screen
//
// Routes: '/settings'

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/workspace_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)?.translate('settingsTitle') ?? 'Settings')),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue.shade800,
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context)?.translate('delayOffset') ?? 'DELAY OFFSET',
              style: const TextStyle(
                color: Colors.white,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}$offset ms',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isPositive
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.translate('hardwareDelayDesc') ?? 'Digunakan untuk kompensasi delay DFPlayer',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: isPositive ? Colors.green : Colors.red,
                    overlayColor: (isPositive ? Colors.green : Colors.red)
                        .withAlpha(32),
                    valueIndicatorColor: Colors.blue.shade800,
                    valueIndicatorTextStyle: const TextStyle(
                      color: Colors.white,
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
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      '+500ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
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
                  spacing: 8,
                  runSpacing: 8,
                  children: [-200, -100, 0, 100, 150, 200, 300].map((val) {
                    final isSelected = offset == val;
                    return ChoiceChip(
                      label: Text('${val > 0 ? '+' : ''}$val'),
                      selected: isSelected,
                      selectedColor: val >= 0
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      onSelected: (_) {
                        workspace.setGlobalOffset(val);
                      },
                      labelStyle: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? (val >= 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800)
                            : Colors.black87,
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
                  icon: Icons.arrow_forward,
                  color: Colors.green,
                  title: AppLocalizations.of(context)?.translate('positiveOffset') ?? 'Offset Positif (+)',
                  desc:
                      AppLocalizations.of(context)?.translate('positiveOffsetDesc') ?? 'Lirik diputar lebih awal dari audio. Gunakan jika lirik terlambat.',
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  icon: Icons.arrow_back,
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
                        icon: const Icon(Icons.restore, size: 18),
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
            color: Colors.blue.shade800,
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context)?.translate('appearance') ?? 'APPEARANCE',
              style: const TextStyle(
                color: Colors.white,
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
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
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
            color: Colors.blue.shade800,
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context)?.translate('languageCaps') ?? 'LANGUAGE',
              style: const TextStyle(
                color: Colors.white,
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

                    leading: const Icon(Icons.language, size: 28),
                    title: Text(l10n?.translate('language') ?? 'Language'),
                    subtitle: Text(
                      localeProvider.locale.languageCode == 'en'
                          ? (l10n?.translate('english') ?? 'English')
                          : (l10n?.translate('indonesian') ?? 'Bahasa Indonesia'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: localeProvider.locale.languageCode == 'en'
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  localeProvider.setLocale(const Locale('en'));
                                },
                          child: const Text('EN'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: localeProvider.locale.languageCode == 'id'
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  localeProvider.setLocale(const Locale('id'));
                                },
                          child: const Text('ID'),
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

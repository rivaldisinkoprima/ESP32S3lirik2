// Settings Screen
//
// Routes: '/settings'

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/workspace_provider.dart';
import '../providers/theme_provider.dart';

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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue.shade800,
            padding: const EdgeInsets.all(12),
            child: const Text(
              'DELAY OFFSET',
              style: TextStyle(
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
                    const Text(
                      'Hardware Delay Offset',
                      style: TextStyle(
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
                  'Digunakan untuk kompensasi delay DFPlayer',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lebih lambat',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade400,
                      ),
                    ),
                    Text(
                      'Lebih cepat',
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
                const Text(
                  'Nilai Cepat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                const Text(
                  'Penjelasan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.arrow_forward,
                  color: Colors.green,
                  title: 'Offset Positif (+)',
                  desc:
                      'Lirik diputar lebih awal dari audio. Gunakan jika lirik terlambat.',
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  icon: Icons.arrow_back,
                  color: Colors.red,
                  title: 'Offset Negatif (-)',
                  desc:
                      'Lirik diputar lebih lambat dari audio. Gunakan jika lirik terlalu cepat.',
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
                                      'Offset dikembalikan ke $_defaultValue ms',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Reset'),
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
            child: const Text(
              'APPEARANCE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: Text(
                  themeProvider.isDarkMode
                      ? 'Dark theme enabled'
                      : 'Light theme enabled',
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

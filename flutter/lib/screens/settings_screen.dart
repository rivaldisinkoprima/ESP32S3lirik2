// Settings Screen
//
// Fungsi:
// - Pengaturan Hardware Delay Offset (-500ms hingga +500ms)
// - Offset 用于 kompensasi DFPlayer delay
//
// Routes: '/settings'

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Column(
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
                const Text('Hardware Delay Offset (Milidetik)'),
                const SizedBox(height: 8),
                const Text(
                  'Digunakan untuk kompensasi delay DFPlayer',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: workspace.globalOffsetMs.toDouble(),
                  min: -500,
                  max: 500,
                  divisions: 100,
                  label: '${workspace.globalOffsetMs} ms',
                  onChanged: (double value) {
                    workspace.setGlobalOffset(value.toInt());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

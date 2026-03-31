import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Hardware Delay Offset (Milidetik)'),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import 'deret_editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lirik Sync Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => Navigator.pushNamed(context, '/sync'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.all(8.0),
            child: const Text(
              'Peringatan: Gunakan file MP3 dari FOLDER 03 (bebas noise)',
              style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: workspace.derets.length,
              itemBuilder: (context, index) {
                final deret = workspace.derets[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${deret.slotNumber}')),
                  title: Text(deret.displayTitle ?? 'Deret ${deret.slotNumber}'),
                  subtitle: Text(deret.isSynced ? 'Synced • ${deret.words.length} words' : 'Not synced'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => DeretEditorScreen(slotNumber: deret.slotNumber)
                      )
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new slot or logic
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

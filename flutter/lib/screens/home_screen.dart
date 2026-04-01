// Home Screen / Workspace Screen
//
// Fungsi:
// - Menampilkan daftar deret (workspace)
// - Warning banner dismissible
// - Navigasi ke DeretEditorScreen untuk edit kata
// - Tombol ke Settings dan BLE Sync
//
// Routes: '/'

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/workspace_provider.dart';
import 'deret_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWarning = true;

  @override
  void initState() {
    super.initState();
    _loadWarningPreference();
  }

  Future<void> _loadWarningPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showWarning = prefs.getBool('show_warning') ?? true;
      });
    }
  }

  Future<void> _dismissWarning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_warning', false);
    if (mounted) {
      setState(() => _showWarning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final syncedCount = workspace.derets.where((d) => d.isSynced).length;

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
          if (_showWarning)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.brown,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gunakan file MP3 dari FOLDER 03 (bebas noise)',
                      style: const TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.brown,
                    ),
                    onPressed: _dismissWarning,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            color: Colors.blue.shade800,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  'DAFTAR DERET',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(77),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${workspace.derets.length} slot',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (syncedCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$syncedCount synced',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: workspace.derets.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: workspace.derets.length,
                    itemBuilder: (context, index) {
                      final deret = workspace.derets[index];
                      return Dismissible(
                        key: ValueKey(deret.slotNumber),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade400,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Deret?'),
                              content: Text(
                                'Hapus Deret ${deret.slotNumber}? Tindakan ini tidak bisa dibatalkan.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Hapus',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          workspace.removeDeret(deret.slotNumber);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Deret ${deret.slotNumber} dihapus',
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: deret.isSynced
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            child: Icon(
                              deret.isSynced
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: deret.isSynced
                                  ? Colors.green
                                  : Colors.grey.shade400,
                            ),
                          ),
                          title: Text(
                            deret.displayTitle ?? 'Deret ${deret.slotNumber}',
                          ),
                          subtitle: Text(
                            deret.isSynced
                                ? '${deret.words.length} kata'
                                : 'Belum disinkronkan',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeretEditorScreen(
                                  slotNumber: deret.slotNumber,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          workspace.addDeret();
          final newSlot = workspace.derets.last.slotNumber;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeretEditorScreen(slotNumber: newSlot),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.playlist_add_circle,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada Deret',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap tombol + untuk membuat',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

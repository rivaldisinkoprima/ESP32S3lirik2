// Home Screen / Workspace Screen
//
// Fungsi:
// - Menampilkan daftar deret (workspace)
// - Warning banner dismissible
// - Bulk import: pilih file audio + JSON dengan multi-select picker
// - Navigasi ke DeretEditorScreen untuk edit kata
// - Tombol ke Settings dan BLE Sync
//
// Routes: '/'

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/workspace_provider.dart';
import '../models/word_entry.dart';
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

  Future<void> _bulkImport() async {
    // Multi-select file picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'json'],
    );

    if (result == null || result.files.isEmpty) return;

    debugPrint('[BULK_IMPORT] Selected ${result.files.length} files');

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mengimpor data...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Process selected files
      final audioMap = <int, String>{}; // slotNumber -> path
      PlatformFile? jsonFile;

      for (final file in result.files) {
        final name = file.name.toLowerCase();
        debugPrint('[BULK_IMPORT] Processing: ${file.name}');

        // Check for JSON file
        if (name.endsWith('.json')) {
          jsonFile = file;
          debugPrint('[BULK_IMPORT] Found JSON: ${file.name}');
        }

        // Check for MP3 files with pattern like "001.mp3"
        if (name.endsWith('.mp3')) {
          final match = RegExp(r'^(\d{3})\.mp3$').firstMatch(name);
          if (match != null) {
            final num = int.parse(match.group(1)!);
            if (num >= 1 && num <= 10) {
              audioMap[num] = file.path!;
              debugPrint('[BULK_IMPORT] Audio slot $num: ${file.name}');
            }
          }
        }
      }

      debugPrint('[BULK_IMPORT] audioMap: $audioMap');

      // Parse JSON data
      Map<String, List<String>> wordData = {};
      if (jsonFile != null) {
        debugPrint('[BULK_IMPORT] JSON file: ${jsonFile.name}');
        debugPrint(
          '[BULK_IMPORT] JSON bytes: ${jsonFile.bytes?.length ?? "null"}',
        );
        debugPrint('[BULK_IMPORT] JSON path: ${jsonFile.path ?? "null"}');

        // Try to read JSON from bytes first, if not available try from path
        try {
          List<int>? bytes = jsonFile.bytes;
          String content;

          if (bytes != null && bytes.isNotEmpty) {
            content = String.fromCharCodes(bytes);
            debugPrint(
              '[BULK_IMPORT] Read JSON from bytes, length: ${bytes.length}',
            );
          } else if (jsonFile.path != null && jsonFile.path!.isNotEmpty) {
            // Fallback: read from file path
            final file = File(jsonFile.path!);
            if (await file.exists()) {
              content = await file.readAsString();
              debugPrint('[BULK_IMPORT] Read JSON from path');
            } else {
              debugPrint('[BULK_IMPORT] JSON file not found at path');
              content = '';
            }
          } else {
            debugPrint('[BULK_IMPORT] No JSON source available');
            content = '';
          }

          if (content.isNotEmpty) {
            debugPrint(
              '[BULK_IMPORT] JSON content preview: ${content.substring(0, content.length > 100 ? 100 : content.length)}',
            );
            final data = jsonDecode(content) as Map<String, dynamic>;
            for (final entry in data.entries) {
              final key = entry.key.toLowerCase();
              debugPrint('[BULK_IMPORT] JSON key found: $key');
              if (key.startsWith('deret_') && entry.value is List) {
                final slotNum = int.tryParse(key.replaceAll('deret_', ''));
                if (slotNum != null && slotNum >= 1 && slotNum <= 10) {
                  wordData['deret_$slotNum'] = (entry.value as List)
                      .map((e) => e.toString())
                      .toList();
                  debugPrint(
                    '[BULK_IMPORT] Words for deret_$slotNum: ${wordData['deret_$slotNum']?.length}',
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[BULK_IMPORT] JSON parse error: $e');
        }
      } else {
        debugPrint('[BULK_IMPORT] No JSON file selected');
      }

      debugPrint('[BULK_IMPORT] wordData keys: ${wordData.keys.toList()}');

      // Update workspace
      final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
      int audioImported = 0;
      int wordsImported = 0;
      final importedDerets = <int>[];

      for (final deret in workspace.derets) {
        final slot = deret.slotNumber;
        bool changed = false;

        // Import audio
        if (audioMap.containsKey(slot)) {
          deret.audioFilePath = audioMap[slot];
          audioImported++;
          changed = true;
        }

        // Import words from JSON
        final wordKey = 'deret_$slot';
        if (wordData.containsKey(wordKey)) {
          final words = wordData[wordKey]!;
          deret.words.clear();
          for (final word in words) {
            final truncated = word.length > 8 ? word.substring(0, 8) : word;
            deret.words.add(WordEntry(timestampMs: 0, word: truncated));
          }
          wordsImported += words.length;
          changed = true;
        }

        if (changed) {
          importedDerets.add(slot);
          workspace.updateDeret(deret);
        }
      }

      debugPrint(
        '[BULK_IMPORT] Result: audio=$audioImported, words=$wordsImported, derets=${importedDerets.length}',
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Import Berhasil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audio: $audioImported file'),
                Text('Kata: $wordsImported kata'),
                Text('Deret: ${importedDerets.length} slot'),
                if (importedDerets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Slot: ${importedDerets.join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            icon: const Icon(Icons.folder_open),
            onPressed: _bulkImport,
            tooltip: 'Import file',
          ),
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

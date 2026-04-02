// Home Screen
//
// Routes: '/'

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../providers/workspace_provider.dart';
import '../models/word_entry.dart';
import '../services/spike_detector.dart';
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'json'],
    );

    if (result == null || result.files.isEmpty) return;

    debugPrint('[BULK_IMPORT] Selected ${result.files.length} files');

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
      final audioMap = <int, String>{};
      PlatformFile? jsonFile;

      for (final file in result.files) {
        final name = file.name.toLowerCase();
        debugPrint('[BULK_IMPORT] Processing: ${file.name}');

        if (name.endsWith('.json')) {
          jsonFile = file;
        }

        if (name.endsWith('.mp3')) {
          final match = RegExp(r'^(\d{3})\.mp3$').firstMatch(name);
          if (match != null) {
            final num = int.parse(match.group(1)!);
            if (num >= 1 && num <= 10) {
              audioMap[num] = file.path!;
            }
          }
        }
      }

      Map<String, List<String>> wordData = {};
      if (jsonFile != null) {
        debugPrint('[BULK_IMPORT] JSON file found: ${jsonFile.name}');

        try {
          List<int>? bytes = jsonFile.bytes;
          String? content;

          // Try bytes first
          if (bytes != null && bytes.isNotEmpty) {
            content = String.fromCharCodes(bytes);
            debugPrint('[BULK_IMPORT] Read JSON from bytes');
          } else if (jsonFile.path != null) {
            // Fallback: read from file path
            final file = File(jsonFile.path!);
            if (await file.exists()) {
              content = await file.readAsString();
              debugPrint('[BULK_IMPORT] Read JSON from path: ${jsonFile.path}');
            }
          }

          if (content != null && content.isNotEmpty) {
            final data = jsonDecode(content) as Map<String, dynamic>;
            debugPrint('[BULK_IMPORT] JSON keys: ${data.keys.toList()}');
            for (final entry in data.entries) {
              final key = entry.key.toLowerCase();
              if (key.startsWith('deret_') && entry.value is List) {
                final slotNum = int.tryParse(key.replaceAll('deret_', ''));
                if (slotNum != null && slotNum >= 1 && slotNum <= 10) {
                  wordData['deret_$slotNum'] = (entry.value as List)
                      .map((e) => e.toString())
                      .toList();
                  debugPrint(
                    '[BULK_IMPORT] Slot $slotNum: ${wordData['deret_$slotNum']?.length} words',
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[BULK_IMPORT] JSON parse error: $e');
        }
      }

      final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
      int audioImported = 0;
      int wordsImported = 0;
      final importedDerets = <int>[];

      for (final deret in workspace.derets) {
        final slot = deret.slotNumber;
        bool changed = false;

        if (audioMap.containsKey(slot)) {
          deret.audioFilePath = audioMap[slot];
          audioImported++;
          changed = true;
        }

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

      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Import Success'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audio: $audioImported file'),
                Text('Lyrics: $wordsImported words'),
                Text('Tracks: ${importedDerets.length} slot'),
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
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _autoDetectAll() async {
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    final deretsWithAudio = workspace.derets
        .where((d) => d.audioFilePath != null && d.audioFilePath!.isNotEmpty)
        .toList();

    if (deretsWithAudio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tracks with audio found')),
      );
      return;
    }

    if (!mounted) return;
    int currentIndex = 0;
    int totalDetected = 0;
    final completedSlots = <int>[];
    final totalDerets = deretsWithAudio.length;

    void Function(void Function())? updateDialog;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          updateDialog = setDialogState;
          return AlertDialog(
            title: const Text('Scan All'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.fourRotatingDots(
                  color: Theme.of(context).primaryColor,
                  size: 50,
                ),
                const SizedBox(height: 16),
                Text('Processing track $currentIndex/$totalDerets'),
                const SizedBox(height: 8),
                Text(
                  '$totalDetected words detected',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );

    try {
      for (int i = 0; i < deretsWithAudio.length; i++) {
        if (!mounted) break;

        final deret = deretsWithAudio[i];
        final audioPath = deret.audioFilePath!;
        currentIndex = i + 1;
        updateDialog?.call(() {});

        try {
          final controller = PlayerController();
          await controller.preparePlayer(
            path: audioPath,
            shouldExtractWaveform: false,
          );

          final duration = await controller.getDuration();
          if (duration > 0) {
            final noOfSamples = duration < 30000
                ? 3000
                : (duration < 120000 ? 2000 : 1000);

            final extractor = WaveformExtractionController();
            final waveformData = await extractor.extractWaveformData(
              path: audioPath,
              noOfSamples: noOfSamples,
            );

            final detectedTimes = await compute(_detectSpikesIsolate, {
              'waveformData': waveformData,
              'totalDurationMs': duration,
              'minGapMs': 600,
              'threshold': 0.015,
            });

            deret.words.clear();
            for (final ts in detectedTimes) {
              deret.words.add(WordEntry(timestampMs: ts, word: ''));
            }
            deret.isSynced = true;
            workspace.updateDeret(deret);

            totalDetected += detectedTimes.length;
            completedSlots.add(deret.slotNumber);
            updateDialog?.call(() {});
          }
          controller.dispose();
        } catch (e) {
          debugPrint('[AUTO_DETECT] Error: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Done'),
            content: Text(
              '$totalDetected words detected in ${completedSlots.length} tracks',
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
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static List<int> _detectSpikesIsolate(Map<String, dynamic> params) {
    return SpikeDetector.detect(
      waveformData: List<double>.from(params['waveformData'] as List),
      totalDurationMs: params['totalDurationMs'] as int,
      minGapMs: params['minGapMs'] as int,
      threshold: (params['threshold'] as num).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final syncedCount = workspace.derets.where((d) => d.isSynced).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lyric Sync Audio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _bulkImport,
            tooltip: 'Import files',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: workspace.derets.isEmpty ? null : _autoDetectAll,
            tooltip: 'Scan all',
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
              padding: const EdgeInsets.all(8),
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
                      'Use noise-free MP3 files for best results',
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
                  'TRACKS',
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
                      return ListTile(
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
                          deret.displayTitle ?? 'Track ${deret.slotNumber}',
                        ),
                        subtitle: Text(
                          deret.isSynced
                              ? '${deret.words.length} words'
                              : 'Not synced',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DeretEditorScreen(slotNumber: deret.slotNumber),
                          ),
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
            'No Tracks Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create a new track',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

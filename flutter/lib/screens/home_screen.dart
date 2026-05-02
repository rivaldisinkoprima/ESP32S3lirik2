import 'package:lucide_icons/lucide_icons.dart';
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
import '../models/deret.dart';
import '../models/word_entry.dart';
import '../services/spike_detector.dart';
import '../l10n/app_localizations.dart';
import 'deret_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWarning = true;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  String tr(String key) => _l10n?.translate(key) ?? key;

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
    final l10n = AppLocalizations.of(context);
    // Ekstrak workspace SEBELUM await pertama untuk menghindari async gap
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return;

    debugPrint('[BULK_IMPORT] Selected ${result.files.length} files');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(tr('importing')),
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

        if (!name.endsWith('.json')) {
          // Match any file with numeric name (1-3 digits) + any extension
          final match = RegExp(r'^(\d{1,3})\.\w+$').firstMatch(name);
          if (match != null) {
            final num = int.parse(match.group(1)!);
            if (num >= 1 && num <= 50) {
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
                if (slotNum != null && slotNum >= 1 && slotNum <= 50) {
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

      // Hitung preview: hanya baca audioMap & wordData, JANGAN ubah workspace di sini
      // Auto-create dan assign sepenuhnya dilakukan di _applyImport
      int audioImported = 0;
      int wordsImported = 0;
      final importedDerets = <int>[];

      // Kumpulkan semua slot dari file yang dipilih
      final allImportSlots = <int>{
        ...audioMap.keys,
        ...wordData.keys
            .map((k) => int.tryParse(k.replaceAll('deret_', '')) ?? 0)
            .where((n) => n > 0),
      };

      for (final slot in allImportSlots.toList()..sort()) {
        bool changed = false;
        if (audioMap.containsKey(slot)) {
          audioImported++;
          changed = true;
        }
        final wordKey = 'deret_$slot';
        if (wordData.containsKey(wordKey)) {
          wordsImported += wordData[wordKey]!.length;
          changed = true;
        }
        if (changed) importedDerets.add(slot);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n?.translate('importPreview') ?? 'Import Preview'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildPreviewItem(
                  LucideIcons.fileAudio,
                  l10n?.translate('audioFiles') ?? 'Audio Files',
                  l10n?.translate('audioFilesCount', ['$audioImported']) ?? '$audioImported files',
                ),
                _buildPreviewItem(
                  LucideIcons.type,
                  l10n?.translate('lyrics') ?? 'Lyrics',
                  l10n?.translate('lyricsWordsCount', ['$wordsImported']) ?? '$wordsImported words',
                ),
                _buildPreviewItem(
                  LucideIcons.playSquare,
                  l10n?.translate('tracks') ?? 'Tracks',
                  l10n?.translate('tracksSlotsCount', ['${importedDerets.length}']) ?? '${importedDerets.length} slots',
                ),
                if (importedDerets.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    l10n?.translate('tracks') ?? 'Tracks',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: importedDerets
                        .map((slot) => Chip(label: Text(l10n?.translate('trackNum', ['$slot']) ?? 'Track $slot')))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n?.translate('cancel') ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _applyImport(audioMap, wordData, importedDerets);
              },
              child: Text(l10n?.translate('import') ?? 'Import'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.translate('importFailed', [e.toString()]) ?? 'Import failed: $e'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('noAudioFound'))));
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
            title: Text(tr('scanAll')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.fourRotatingDots(
                  color: Theme.of(context).primaryColor,
                  size: 50,
                ),
                const SizedBox(height: 16),
                Text(
                  _l10n?.translate('processingTrack', ['$currentIndex', '$totalDerets']) ?? 'Processing track $currentIndex of $totalDerets',
                ),
                const SizedBox(height: 8),
                Text(
                  _l10n?.translate('wordsDetected', ['$totalDetected']) ?? '$totalDetected words detected',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('cancel')),
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

            // Preserve existing words when possible, update timestamps
            final List<WordEntry> newWords = <WordEntry>[];
            final int wordCount = deret.words.length;
            final int detectedCount = detectedTimes.length;

            if (wordCount > 0 && detectedCount > 0) {
              // When we have both existing words and detected timestamps,
              // map them by position (up to the minimum count)
              final int mapCount = wordCount < detectedCount
                  ? wordCount
                  : detectedCount;
              for (int i = 0; i < mapCount; i++) {
                final existingWord = deret.words[i].word;
                final newTimestamp = detectedTimes[i];
                newWords.add(
                  WordEntry(timestampMs: newTimestamp, word: existingWord),
                );
              }

              // If we detected more timestamps than existing words, add new empty words
              if (detectedCount > wordCount) {
                for (int i = wordCount; i < detectedCount; i++) {
                  newWords.add(
                    WordEntry(timestampMs: detectedTimes[i], word: ''),
                  );
                }
              }
              // If we have more existing words than detected timestamps, keep the extra words with timestamp 0
              if (wordCount > detectedCount) {
                for (int i = detectedCount; i < wordCount; i++) {
                  newWords.add(deret.words[i]);
                }
              }
            } else if (detectedCount > 0) {
              // No existing words, create new ones from detected timestamps
              for (final ts in detectedTimes) {
                newWords.add(WordEntry(timestampMs: ts, word: ''));
              }
            } else {
              // No detected timestamps, keep existing words
              newWords.addAll(deret.words);
            }

            deret.words.clear();
            deret.words.addAll(newWords);
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
            title: Text(_l10n?.translate('done') ?? 'Done'),
            content: Text(
              _l10n?.translate('wordsDetectedIn', ['$totalDetected', '${completedSlots.length}']) ?? '$totalDetected words detected in ${completedSlots.length} tracks',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_l10n?.translate('ok') ?? 'OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n?.translate('failed', [e.toString()]) ?? 'Failed: $e'), backgroundColor: Colors.red),
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Image.asset('assets/logo1.png'),
        ),
        title: Text(l10n?.translate('appName') ?? 'Lirik Sync'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.folderOpen),
            onPressed: _bulkImport,
            tooltip: l10n?.translate('importFiles') ?? 'Import files',
          ),
          IconButton(
            icon: const Icon(LucideIcons.sparkles),
            onPressed: workspace.derets.isEmpty ? null : _autoDetectAll,
            tooltip: l10n?.translate('scanAll') ?? 'Scan all',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showWarning)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n?.translate('noiseWarning') ?? 'Use noise-free MP3 files for best results',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
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
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  l10n?.translate('tracksAllCaps') ?? 'TRACKS',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n?.translate('tracksSlotsCount', ['${workspace.derets.length}']) ?? '${workspace.derets.length} slots',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n?.translate('syncedCount', ['$syncedCount']) ?? '$syncedCount synced',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
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
                    padding: const EdgeInsets.only(top: 12, bottom: 88, left: 16, right: 16),
                    itemCount: workspace.derets.length,
                    itemBuilder: (context, index) {
                      final deret = workspace.derets[index];
                      return Dismissible(
                        key: ValueKey(deret.slotNumber.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(LucideIcons.trash2, color: Theme.of(context).colorScheme.onError),
                        ),
                        onDismissed: (direction) {
                          final slotNum = deret.slotNumber;
                          workspace.removeDeret(slotNum);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n?.translate('trackDeleted', ['$slotNum']) ?? 'Track $slotNum deleted'),
                              action: SnackBarAction(
                                label: l10n?.translate('undo') ?? 'UNDO',
                                onPressed: () {
                                  workspace.restoreLastDeleted();
                                },
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          shadowColor: Colors.black.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DeretEditorScreen(slotNumber: deret.slotNumber),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: deret.isSynced
                                        ? Theme.of(context).colorScheme.secondaryContainer
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    deret.isSynced
                                        ? LucideIcons.checkCircle
                                        : LucideIcons.music,
                                    color: deret.isSynced
                                        ? Theme.of(context).colorScheme.onSecondaryContainer
                                        : Theme.of(context).colorScheme.outline,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  deret.displayTitle ?? l10n?.translate('trackNum', ['${deret.slotNumber}']) ?? 'Track ${deret.slotNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  deret.isSynced
                                      ? l10n?.translate('wordsCount', ['${deret.words.length}']) ?? '${deret.words.length} words'
                                      : l10n?.translate('notSynced') ?? 'Not synced',
                                  style: TextStyle(
                                    color: deret.isSynced ? Colors.green.shade600 : Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: deret.isSynced ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                                trailing: Icon(LucideIcons.chevronRight, color: Theme.of(context).colorScheme.outlineVariant),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
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
        icon: const Icon(LucideIcons.plus),
        label: Text(l10n?.translate('Add') ?? 'New Track', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.folderPlus,
            size: 80,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _l10n?.translate('noTracksYet') ?? 'No Tracks Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _l10n?.translate('tapPlusToCreate') ?? 'Tap + to create a new track',
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyImport(
    Map<int, String> audioMap,
    Map<String, List<String>> wordData,
    List<int> importedSlots,
  ) {
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    int audioImported = 0;
    int wordsImported = 0;

    // Step 1: Kumpulkan semua slot dari file import
    final allSlots = <int>{
      ...audioMap.keys,
      ...wordData.keys
          .map((k) => int.tryParse(k.replaceAll('deret_', '')) ?? 0)
          .where((n) => n > 0),
    };

    // Step 1.5: Hapus slot lama yang TIDAK ada di dalam file import baru
    final currentSlots = workspace.derets.map((d) => d.slotNumber).toList();
    for (final slot in currentSlots) {
      if (!allSlots.contains(slot)) {
        workspace.removeDeret(slot);
      }
    }

    // Step 2: Auto-create slot yang belum ada (satu per satu, synchronous)
    for (final slot in allSlots.toList()..sort()) {
      if (!workspace.derets.any((d) => d.slotNumber == slot)) {
        workspace.addDeretWithSlot(slot);
      }
    }

    // Step 3: Ambil snapshot list SETELAH semua slot terbuat
    final currentDerets = List<Deret>.from(workspace.derets);

    // Step 4: Assign audio & kata ke setiap deret berdasarkan slot
    for (final slot in allSlots.toList()..sort()) {
      final deret = currentDerets.firstWhere(
        (d) => d.slotNumber == slot,
        orElse: () => Deret(slotNumber: slot),
      );

      bool changed = false;

      if (audioMap.containsKey(slot)) {
        deret.audioFilePath = audioMap[slot];
        audioImported++;
        changed = true;
        debugPrint('[IMPORT] Slot $slot ← audio: ${audioMap[slot]}');
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
        deret.isSynced = false; // ★ Reset status sync karena lirik berubah
      }

      // Step 5: Simpan ke workspace (triggers _saveDerets)
      if (changed) {
        workspace.updateDeret(deret);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n?.translate('importSuccess') ?? 'Import Success'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_l10n?.translate('audioFilesCount', ['$audioImported']) ?? 'Audio: $audioImported files'),
            Text(_l10n?.translate('lyricsWordsCount', ['$wordsImported']) ?? 'Lyrics: $wordsImported words'),
            Text(_l10n?.translate('tracksSlotsCount', ['${importedSlots.length}']) ?? 'Tracks: ${importedSlots.length} slots'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n?.translate('ok') ?? 'OK'),
          ),
        ],
      ),
    );
  }
}

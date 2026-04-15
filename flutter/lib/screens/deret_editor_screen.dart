import 'package:lucide_icons/lucide_icons.dart';
// Track Editor Screen
//
// Routes: Via Navigator.push from HomeScreen

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../models/deret.dart';
import '../models/word_entry.dart';
import '../providers/workspace_provider.dart';
import '../services/spike_detector.dart';
import '../l10n/app_localizations.dart';

class _ProgressPainter extends CustomPainter {
  final double progress;
  final List<int> wordTimestamps;
  final List<String> wordLabels;
  final int totalDuration;
  final int activeIndex;

  _ProgressPainter({
    required this.progress,
    required this.wordTimestamps,
    required this.wordLabels,
    required this.totalDuration,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = 4.0;
    final markerHeight = 16.0;
    final markerWidth = 2.0;
    final topPadding = 20.0;

    final bgPaint = Paint()
      ..color = Colors.grey.withAlpha(77)
      ..strokeWidth = barHeight
      ..strokeCap = StrokeCap.round;

    final livePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = barHeight
      ..strokeCap = StrokeCap.round;

    final markerPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = markerWidth
      ..strokeCap = StrokeCap.round;

    final activeMarkerPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = markerWidth + 1
      ..strokeCap = StrokeCap.round;

    final y = topPadding + (markerHeight - barHeight) / 2;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), bgPaint);

    if (progress > 0) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * progress, y),
        livePaint,
      );
    }

    for (int i = 0; i < wordTimestamps.length; i++) {
      final ts = wordTimestamps[i];
      if (ts <= 0 || totalDuration <= 0) continue;
      final xPos = (ts / totalDuration) * size.width;
      final isActive = i == activeIndex;
      final paint = isActive ? activeMarkerPaint : markerPaint;

      canvas.drawLine(
        Offset(xPos, topPadding),
        Offset(xPos, topPadding + markerHeight),
        paint,
      );

      if (isActive && i < wordLabels.length && wordLabels[i].isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: wordLabels[i],
            style: const TextStyle(
              fontSize: 10,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            xPos - textPainter.width / 2,
            topPadding - textPainter.height - 2,
          ),
        );
      }
    }

    if (progress > 0 && progress < 1) {
      final playheadX = size.width * progress;
      final playheadPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(playheadX - 6, y - 8)
        ..lineTo(playheadX + 6, y - 8)
        ..lineTo(playheadX, y + 2)
        ..close();
      canvas.drawPath(path, playheadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeIndex != activeIndex;
  }
}

class DeretEditorScreen extends StatefulWidget {
  final int slotNumber;

  const DeretEditorScreen({super.key, required this.slotNumber});

  @override
  State<DeretEditorScreen> createState() => _DeretEditorScreenState();
}

class _DeretEditorScreenState extends State<DeretEditorScreen> {
  late PlayerController _playerController;
  late Deret _editingDeret;
  bool _isPlayerReady = false;
  bool _isLoadingWaveform = false;
  final bool _isDetecting = false;
  int _detectedSpikesCount = 0;
  int _currentPlayingIndex = -1;
  StreamSubscription? _durationSubscription;

  AppLocalizations? get _l10n => AppLocalizations.of(context);
  final ScrollController _scrollController = ScrollController();

  final List<TextEditingController> _wordControllers = [];
  final List<TextEditingController> _timestampControllers = [];

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController();

    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    _editingDeret = workspace.derets.firstWhere(
      (d) => d.slotNumber == widget.slotNumber,
    );

    for (var w in _editingDeret.words) {
      _wordControllers.add(TextEditingController(text: w.word));
      _timestampControllers.add(
        TextEditingController(text: w.timestampMs.toString()),
      );
    }

    if (_editingDeret.audioFilePath != null) {
      _preparePlayer(_editingDeret.audioFilePath!);
    }
  }

  Future<void> _preparePlayer(String path) async {
    setState(() => _isLoadingWaveform = true);
    try {
      await _playerController.preparePlayer(
        path: path,
        shouldExtractWaveform: true,
        noOfSamples: 500,
      );

      _playerController.onPlayerStateChanged.listen((state) {
        setState(() {});
        if (state == PlayerState.stopped) {
          setState(() => _currentPlayingIndex = -1);
        }
      });

      setState(() {
        _isPlayerReady = true;
        _isLoadingWaveform = false;
      });
    } catch (e) {
      debugPrint('Prepare player error: $e');
      setState(() => _isLoadingWaveform = false);
    }
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      setState(() => _editingDeret.audioFilePath = path);
      _preparePlayer(path);
    }
  }

  void _addWord() {
    setState(() {
      _wordControllers.add(TextEditingController());
      _timestampControllers.add(TextEditingController(text: '0'));
      _editingDeret.words.add(WordEntry(timestampMs: 0, word: ""));
    });
  }

  void _removeWord(int index) {
    setState(() {
      _wordControllers[index].dispose();
      _timestampControllers[index].dispose();
      _wordControllers.removeAt(index);
      _timestampControllers.removeAt(index);
      _editingDeret.words.removeAt(index);
    });
  }

  Future<void> _autoDetect() async {
    if (!_isPlayerReady) return;
    if (_editingDeret.audioFilePath == null) return;

    final path = _editingDeret.audioFilePath!;
    debugPrint('[AUTO_DETECT] === START ===');
    debugPrint('[AUTO_DETECT] Path: $path');

    final extension = path.split('.').last.toLowerCase();
    debugPrint('[AUTO_DETECT] Extension: $extension');

    const supportedFormats = ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'wma'];
    if (!supportedFormats.contains(extension)) {
      debugPrint('[AUTO_DETECT] FAIL: Unsupported format');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _l10n?.translate('formatNotSupported', [extension, supportedFormats.join(', ')]) ?? 'Format .$extension tidak didukung. Gunakan: ${supportedFormats.join(', ')}',
          ),
        ),
      );
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      debugPrint('[AUTO_DETECT] FAIL: File not found');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n?.translate('audioFileNotFound') ?? 'File audio tidak ditemukan')),
      );
      return;
    }

    final fileSize = await file.length();
    debugPrint('[AUTO_DETECT] File size: ${fileSize ~/ 1024} KB');

    if (fileSize > 100 * 1024 * 1024) {
      debugPrint('[AUTO_DETECT] FAIL: File too large');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n?.translate('fileTooLarge') ?? 'File terlalu besar (maks 100MB)')),
      );
      return;
    }

    if (!mounted) return;
    var loadingMessage = _l10n?.translate('preparing') ?? 'Mempersiapkan...';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(loadingMessage),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(_l10n?.translate('cancel') ?? 'Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      loadingMessage = _l10n?.translate('processing') ?? 'Processing...';
      if (mounted) setState(() {});
      debugPrint('[AUTO_DETECT] Step 3: Getting duration...');

      final sw = Stopwatch()..start();
      final duration = await _playerController.getDuration().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException(_l10n?.translate('timeoutDuration') ?? 'Timeout membaca durasi'),
      );
      sw.stop();
      debugPrint(
        '[AUTO_DETECT] Duration: ${duration}ms (${sw.elapsedMilliseconds}ms)',
      );

      if (duration <= 0) {
        debugPrint('[AUTO_DETECT] FAIL: Invalid duration');
        throw Exception(_l10n?.translate('invalidDuration') ?? 'Durasi audio tidak valid');
      }

      final noOfSamples = _adaptiveSampleCount(duration);
      debugPrint('[AUTO_DETECT] Adaptive samples: $noOfSamples');

      loadingMessage = _l10n?.translate('validatingAudio') ?? 'Memvalidasi file audio...';
      if (mounted) setState(() {});
      debugPrint('[AUTO_DETECT] Step 4b: Pre-check decoding...');

      final preCheckExtractor = WaveformExtractionController();
      List<double> preCheckData;
      try {
        preCheckData = await preCheckExtractor
            .extractWaveformData(path: path, noOfSamples: 100)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw TimeoutException(_l10n?.translate('timeoutValidation') ?? 'Timeout validasi file (10 detik)'),
            );
      } catch (e) {
        debugPrint('[AUTO_DETECT] FAIL: Pre-check extraction error - $e');
        throw Exception(
          _l10n?.translate('failedReadAudio') ?? 'Gagal membaca file audio. Pastikan file tidak corrupt dan format didukung.',
        );
      }

      if (preCheckData.isEmpty) {
        debugPrint('[AUTO_DETECT] FAIL: Pre-check returned empty data');
        throw Exception(
          _l10n?.translate('cannotDecodeAudio') ?? 'File audio tidak bisa di-decode. Coba convert ke WAV atau MP3 standar 128kbps CBR.',
        );
      }

      final preCheckMax = preCheckData.reduce((a, b) => a > b ? a : b);
      final preCheckAvg =
          preCheckData.reduce((a, b) => a + b) / preCheckData.length;
      debugPrint(
        '[AUTO_DETECT] Pre-check: max=$preCheckMax, avg=${preCheckAvg.toStringAsFixed(4)}',
      );

      if (preCheckMax < 0.001 && preCheckAvg.abs() < 0.001) {
        debugPrint('[AUTO_DETECT] FAIL: All samples are zero - decoder issue');
        throw Exception(
          _l10n?.translate('decoderIssueAndroid') ?? 'File audio tidak kompatibel dengan decoder Android. '
          'Kemungkinan: VBR, corrupt, atau format tidak standar. '
          'Solusi: Convert ke WAV atau MP3 128kbps CBR.',
        );
      }

      loadingMessage = _l10n?.translate('extractingWaveform', ['$noOfSamples']) ?? 'Mengekstrak waveform ($noOfSamples samples)...';
      if (mounted) setState(() {});
      debugPrint('[AUTO_DETECT] Step 5: Extracting waveform...');

      final extractor = WaveformExtractionController();
      List<double> data;
      final extractSw = Stopwatch()..start();
      try {
        data = await extractor
            .extractWaveformData(path: path, noOfSamples: noOfSamples)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                'Timeout ekstraksi waveform (30 detik)',
              ),
            );
        extractSw.stop();
        debugPrint(
          '[AUTO_DETECT] Extracted ${data.length} samples in ${extractSw.elapsedMilliseconds}ms',
        );
      } finally {
        // Extractor is short-lived, no dispose method available
      }

      if (data.isEmpty) {
        debugPrint('[AUTO_DETECT] FAIL: Empty waveform data');
        throw Exception('Waveform data kosong');
      }

      final maxVal = data.reduce((a, b) => a > b ? a : b);
      final minVal = data.reduce((a, b) => a < b ? a : b);
      final avgVal = data.reduce((a, b) => a + b) / data.length;
      debugPrint(
        '[AUTO_DETECT] Data stats: min=$minVal, max=$maxVal, avg=${avgVal.toStringAsFixed(4)}',
      );
      debugPrint('[AUTO_DETECT] First 10 samples: ${data.take(10).join(', ')}');

      loadingMessage = _l10n?.translate('detectingSpikes') ?? 'Mendeteksi spike...';
      if (mounted) setState(() {});
      debugPrint('[AUTO_DETECT] Step 6: Detecting spikes in isolate...');

      final detectSw = Stopwatch()..start();
      final detectedTimes =
          await compute(_detectSpikesIsolate, {
            'waveformData': data,
            'totalDurationMs': duration,
            'minGapMs': 600,
            'threshold': 0.015,
          }).timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Timeout deteksi spike (15 detik)'),
          );
      detectSw.stop();
      debugPrint(
        '[AUTO_DETECT] Detected ${detectedTimes.length} spikes in ${detectSw.elapsedMilliseconds}ms',
      );
      debugPrint(
        '[AUTO_DETECT] Spike times: ${detectedTimes.take(20).join(', ')}${detectedTimes.length > 20 ? '...' : ''}',
      );

      if (!mounted) return;
      debugPrint('[AUTO_DETECT] Step 7: Updating UI state...');
      setState(() {
        _detectedSpikesCount = detectedTimes.length;
        for (int i = 0; i < detectedTimes.length; i++) {
          if (i < _editingDeret.words.length) {
            _editingDeret.words[i].timestampMs = detectedTimes[i];
            _timestampControllers[i].text = detectedTimes[i].toString();
          } else {
            _editingDeret.words.add(
              WordEntry(timestampMs: detectedTimes[i], word: _l10n?.translate('newWordDefault') ?? "NEW"),
            );
            _wordControllers.add(TextEditingController(text: _l10n?.translate('newWordDefault') ?? "NEW"));
            _timestampControllers.add(
              TextEditingController(text: detectedTimes[i].toString()),
            );
          }
        }
        _editingDeret.isSynced = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n?.translate('spikesDetectedDetail', ['${detectedTimes.length}']) ?? 'Berhasil mendeteksi ${detectedTimes.length} spike'),
          ),
        );
      }
      debugPrint('[AUTO_DETECT] === SUCCESS ===');
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('[AUTO_DETECT] FAIL: Timeout - $e');
      debugPrint('[AUTO_DETECT] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n?.translate('processTooLong', [e.toString()]) ?? 'Process took too long: $e')));
      }
    } catch (e, stackTrace) {
      debugPrint('[AUTO_DETECT] FAIL: $e');
      debugPrint('[AUTO_DETECT] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n?.translate('error', [e.toString()]) ?? 'Error: $e')));
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  int _adaptiveSampleCount(int durationMs) {
    if (durationMs < 30000) return 3000;
    if (durationMs < 120000) return 2000;
    if (durationMs < 300000) return 1000;
    return 500;
  }

  static List<int> _detectSpikesIsolate(Map<String, dynamic> params) {
    return SpikeDetector.detect(
      waveformData: List<double>.from(params['waveformData'] as List),
      totalDurationMs: params['totalDurationMs'] as int,
      minGapMs: params['minGapMs'] as int,
      threshold: (params['threshold'] as num).toDouble(),
    );
  }

  Future<void> _playFromWord(int index) async {
    if (!_isPlayerReady) return;
    if (index < 0 || index >= _editingDeret.words.length) return;

    final timestamp = _editingDeret.words[index].timestampMs;

    if (_currentPlayingIndex == index) {
      await _playerController.pausePlayer();
      await _durationSubscription?.cancel();
      _durationSubscription = null;
      setState(() => _currentPlayingIndex = -1);
      return;
    }

    try {
      await _durationSubscription?.cancel();
      _durationSubscription = null;

      final state = _playerController.playerState;

      if (state == PlayerState.playing) {
        await _playerController.seekTo(timestamp);
      } else if (state == PlayerState.paused) {
        await _playerController.startPlayer();
        await Future.delayed(const Duration(milliseconds: 50));
        await _playerController.seekTo(timestamp);
      } else {
        await _playerController.startPlayer();
        await Future.delayed(const Duration(milliseconds: 100));
        await _playerController.seekTo(timestamp);
      }

      setState(() => _currentPlayingIndex = index);

      _durationSubscription = _playerController.onCurrentDurationChanged.listen(
        (duration) {
          if (!mounted) return;
          _updateCurrentPlayingIndex(duration);
        },
      );
    } catch (e) {
      debugPrint('Play error: $e');
      setState(() => _currentPlayingIndex = -1);
    }
  }

  void _updateCurrentPlayingIndex(int currentMs) {
    if (!_isPlayerReady) return;
    if (_currentPlayingIndex < 0) return;

    int newIndex = -1;
    for (int i = 0; i < _editingDeret.words.length; i++) {
      if (currentMs >= _editingDeret.words[i].timestampMs) {
        newIndex = i;
      }
    }

    if (newIndex != _currentPlayingIndex) {
      setState(() => _currentPlayingIndex = newIndex);
      _scrollToActiveWord(newIndex);
    }

    if (_playerController.playerState != PlayerState.playing &&
        _currentPlayingIndex >= 0) {
      if (_editingDeret.words.isNotEmpty &&
          currentMs >= _editingDeret.words.last.timestampMs + 500) {
        setState(() => _currentPlayingIndex = -1);
      }
    }
  }

  void _scrollToActiveWord(int index) {
    if (!_scrollController.hasClients) return;

    // Add some padding to prevent scrolling when word is near edges
    final double viewportPadding = 20.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = index * 56.0; // Match item height in build
    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;

    // Only scroll if word is significantly outside viewport
    if (targetOffset < currentOffset - viewportPadding ||
        targetOffset > currentOffset + viewportHeight - viewportPadding) {
      // Ensure we don't scroll beyond bounds
      final double clampedOffset = targetOffset.clamp(0.0, maxOffset);

      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic, // More responsive than easeInOut
      );
    }
  }

  Widget _buildProgressBar() {
    return FutureBuilder<int>(
      future: _playerController.getDuration(),
      builder: (context, durationSnapshot) {
        if (!durationSnapshot.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final totalDuration = durationSnapshot.data!;
        return StreamBuilder<int>(
          stream: _playerController.onCurrentDurationChanged,
          builder: (context, currentSnapshot) {
            final currentMs = currentSnapshot.data ?? 0;
            final progress = totalDuration > 0
                ? currentMs / totalDuration
                : 0.0;

            final wordLabels = _editingDeret.words
                .map((w) => w.word.isNotEmpty ? w.word : '${w.timestampMs}ms')
                .toList();

            return Column(
              children: [
                GestureDetector(
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final dx = details.localPosition.dx;
                    final width = box.size.width;
                    final tapProgress = (dx / width).clamp(0.0, 1.0);
                    final seekMs = (tapProgress * totalDuration).toInt();
                    _seekToPosition(seekMs);
                  },
                  child: SizedBox(
                    height: 40,
                    child: CustomPaint(
                      size: Size(double.infinity, 40),
                      painter: _ProgressPainter(
                        progress: progress,
                        wordTimestamps: _editingDeret.words
                            .map((w) => w.timestampMs)
                            .toList(),
                        wordLabels: wordLabels,
                        totalDuration: totalDuration,
                        activeIndex: _currentPlayingIndex,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(currentMs / 1000).toStringAsFixed(1)}s / ${(totalDuration / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _seekToPosition(int seekMs) async {
    if (!_isPlayerReady) return;
    try {
      final state = _playerController.playerState;
      if (state == PlayerState.stopped) {
        await _playerController.startPlayer();
        await Future.delayed(const Duration(milliseconds: 100));
      } else if (state == PlayerState.paused) {
        await _playerController.startPlayer();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      await _playerController.seekTo(seekMs);
      _updateCurrentPlayingIndex(seekMs);
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  void _save() {
    for (int i = 0; i < _wordControllers.length; i++) {
      String val = _wordControllers[i].text.toUpperCase();
      if (val.length > 8) val = val.substring(0, 8);
      _editingDeret.words[i].word = val;

      final tsText = _timestampControllers[i].text;
      final ts = int.tryParse(tsText);
      if (ts != null) {
        _editingDeret.words[i].timestampMs = ts;
      }
    }

    HapticFeedback.lightImpact();
    Provider.of<WorkspaceProvider>(
      context,
      listen: false,
    ).updateDeret(_editingDeret);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n?.translate('savedSuccessfully', ['${widget.slotNumber}']) ?? 'Track ${widget.slotNumber} saved successfully'),
        duration: const Duration(seconds: 1),
      ),
    );
    Navigator.pop(context);
  }

  void _addMissingWords() {
    final missing = _detectedSpikesCount - _wordControllers.length;
    if (missing <= 0) return;
    setState(() {
      for (int i = 0; i < missing; i++) {
        _wordControllers.add(TextEditingController());
        _timestampControllers.add(TextEditingController(text: '0'));
        _editingDeret.words.add(WordEntry(timestampMs: 0, word: ""));
      }
    });
  }

  void _removeExtraWords() {
    final extra = _wordControllers.length - _detectedSpikesCount;
    if (extra <= 0) return;
    setState(() {
      for (int i = 0; i < extra; i++) {
        final idx = _wordControllers.length - 1;
        _wordControllers[idx].dispose();
        _timestampControllers[idx].dispose();
        _wordControllers.removeAt(idx);
        _timestampControllers.removeAt(idx);
        _editingDeret.words.removeAt(idx);
      }
    });
  }

  Future<void> _importWordsFromJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final deretKey = 'deret_${widget.slotNumber}';
      if (!data.containsKey(deretKey)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l10n?.translate('jsonMissingData', [deretKey]) ?? 'File does not contain data for "$deretKey". '
              'Ensure format: {"track_${widget.slotNumber}": ["WORD1", "WORD2", ...]}',
            ),
          ),
        );
        return;
      }

      final words = (data[deretKey] as List).map((e) => e.toString()).toList();

      setState(() {
        // Clear existing words
        for (var c in _wordControllers) {
          c.dispose();
        }
        for (var c in _timestampControllers) {
          c.dispose();
        }
        _wordControllers.clear();
        _timestampControllers.clear();
        _editingDeret.words.clear();

        // Add new words
        for (final word in words) {
          final truncated = word.length > 8 ? word.substring(0, 8) : word;
          _editingDeret.words.add(WordEntry(timestampMs: 0, word: truncated));
          _wordControllers.add(TextEditingController(text: truncated));
          _timestampControllers.add(TextEditingController(text: '0'));
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l10n?.translate('wordsImportedToTrack', ['${words.length}', '${widget.slotNumber}']) ?? '${words.length} words imported to Track ${widget.slotNumber}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read JSON file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _playerController.dispose();
    _scrollController.dispose();
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    for (var controller in _timestampControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(_l10n?.translate('discardChanges') ?? 'Discard Changes?'),
              content: Text(
                _l10n?.translate('unsavedChanges') ?? 'You have unsaved changes. Are you sure you want to go back?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(_l10n?.translate('cancel') ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    _l10n?.translate('discard') ?? 'Discard',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_l10n?.translate('editTrack', ['${widget.slotNumber}']) ?? 'Edit Track ${widget.slotNumber}'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.check),
                onPressed: _save,
                tooltip: _l10n?.translate('save') ?? 'Save',
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  _l10n?.translate('selectAudio') ?? 'SELECT AUDIO',
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
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _editingDeret.audioFilePath?.split('/').last ??
                                (_l10n?.translate('selectAudioFile') ?? 'Select audio file...'),
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickAudioFile,
                          icon: const Icon(LucideIcons.fileAudio),
                          label: Text(_l10n?.translate('open') ?? 'Open'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _l10n?.translate('importLyricsDesc', ['${widget.slotNumber}']) ?? 'Track ${widget.slotNumber}: Import lyrics from JSON file',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _importWordsFromJson,
                          icon: const Icon(LucideIcons.upload, size: 18),
                          label: Text(_l10n?.translate('import') ?? 'Import'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_isPlayerReady)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildProgressBar(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _playerController.playerState ==
                                      PlayerState.playing
                                  ? LucideIcons.pause
                                  : LucideIcons.play,
                            ),
                            onPressed: () async {
                              if (_playerController.playerState ==
                                  PlayerState.playing) {
                                await _playerController.pausePlayer();
                                setState(() => _currentPlayingIndex = -1);
                              } else {
                                await _playerController.startPlayer();
                              }
                              setState(() {});
                            },
                          ),
                          ElevatedButton.icon(
                            onPressed: _isDetecting ? null : _autoDetect,
                            icon: _isDetecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.sparkles),
                            label: Text(_l10n?.translate('detectWords') ?? 'Detect Words'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_isLoadingWaveform)
                Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  highlightColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Container(
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

              if (_detectedSpikesCount > 0 &&
                  _detectedSpikesCount != _wordControllers.length)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.alertTriangle, color: Theme.of(context).colorScheme.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _l10n?.translate('spikeWordMismatch', ['$_detectedSpikesCount', '${_wordControllers.length}']) ?? 'Spike ($_detectedSpikesCount) != Words (${_wordControllers.length})',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (_detectedSpikesCount > _wordControllers.length)
                            ElevatedButton.icon(
                              onPressed: _addMissingWords,
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: Text(_l10n?.translate('addWord') ?? 'Add Word'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                            ),
                          if (_wordControllers.length > _detectedSpikesCount)
                            ElevatedButton.icon(
                              onPressed: _removeExtraWords,
                              icon: const Icon(LucideIcons.minus, size: 16),
                              label: Text(_l10n?.translate('removeExtra') ?? 'Remove extra'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

              const Divider(),
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  'WORDS',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _wordControllers.length,
                  itemBuilder: (context, index) {
                    final isActive = _currentPlayingIndex == index;
                    return Container(
                      color: isActive ? Theme.of(context).colorScheme.tertiaryContainer.withAlpha(100) : null,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: Text('${index + 1}°'),
                        title: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: _timestampControllers[index],
                                decoration: InputDecoration(
                                  hintText: _l10n?.translate('ms') ?? 'ms',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                keyboardType: TextInputType.numberWithOptions(
                                  signed: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^-?\d*'),
                                  ),
                                ],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isActive
                                      ? Colors.orange
                                      : Colors.blueGrey,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _wordControllers[index],
                                decoration: InputDecoration(
                                  hintText: _l10n?.translate('maxChars') ?? 'MAX-8',
                                  isDense: true,
                                  counterText:
                                      '${_wordControllers[index].text.length}/8',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                maxLength: 8,
                                maxLengthEnforcement:
                                    MaxLengthEnforcement.enforced,
                                textCapitalization:
                                    TextCapitalization.characters,
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isActive
                                    ? LucideIcons.pauseCircle
                                    : LucideIcons.playCircle,
                                color: isActive ? Colors.orange : Colors.green,
                                size: 28,
                              ),
                              onPressed: () async {
                                if (isActive) {
                                  await _playerController.pausePlayer();
                                  await _durationSubscription?.cancel();
                                  _durationSubscription = null;
                                  setState(() => _currentPlayingIndex = -1);
                                } else {
                                  await _playFromWord(index);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.minusCircle,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _removeWord(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: _addWord,
                  icon: const Icon(LucideIcons.plus),
                  label: Text(_l10n?.translate('addWord') ?? 'Add Word'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Deret Editor Screen
//
// Fungsi:
// - Pilih file MP3 audio
// - Auto-Detect Spikes: Deteksi timing kata dari waveform
// - Edit kata (maks 8 karakter) dan timestamp
// - Preview: Play audio dari timestamp tertentu
// - Visual: Waveform dengan progress dan active word highlight
// - Simpan ke workspace
//
// Routes: Via Navigator.push dari HomeScreen

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../models/deret.dart';
import '../models/word_entry.dart';
import '../providers/workspace_provider.dart';
import '../services/spike_detector.dart';

class _ProgressPainter extends CustomPainter {
  final double progress;
  final List<int> wordTimestamps;
  final int totalDuration;
  final int activeIndex;

  _ProgressPainter({
    required this.progress,
    required this.wordTimestamps,
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

    // Background bar
    canvas.drawLine(Offset(0, y), Offset(size.width, y), bgPaint);

    // Progress bar
    if (progress > 0) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * progress, y),
        livePaint,
      );
    }

    // Word markers
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

      // Draw word label
      if (i < wordTimestamps.length) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              fontSize: 9,
              color: isActive ? Colors.red : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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

    // Playhead triangle
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
  _DeretEditorScreenState createState() => _DeretEditorScreenState();
}

class _DeretEditorScreenState extends State<DeretEditorScreen> {
  late PlayerController _playerController;
  late Deret _editingDeret;
  bool _isPlayerReady = false;
  bool _isLoadingWaveform = false;
  bool _isDetecting = false;
  int _detectedSpikesCount = 0;
  int _currentPlayingIndex = -1;
  StreamSubscription? _durationSubscription;

  final List<TextEditingController> _wordControllers = [];

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController();

    // Copy deret data from provider
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    _editingDeret = workspace.derets.firstWhere(
      (d) => d.slotNumber == widget.slotNumber,
    );

    // Fill word controllers
    for (var w in _editingDeret.words) {
      _wordControllers.add(TextEditingController(text: w.word));
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

      // Listen for player state changes
      _playerController.onPlayerStateChanged.listen((state) {
        setState(() {});
        // If player stopped naturally, reset active index
        if (state == PlayerState.stopped) {
          setState(() {
            _currentPlayingIndex = -1;
          });
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
      type: FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      setState(() {
        _editingDeret.audioFilePath = path;
      });
      _preparePlayer(path);
    }
  }

  void _addWord() {
    setState(() {
      _wordControllers.add(TextEditingController());
      _editingDeret.words.add(WordEntry(timestampMs: 0, word: ""));
    });
  }

  void _removeWord(int index) {
    setState(() {
      _wordControllers[index].dispose();
      _wordControllers.removeAt(index);
      _editingDeret.words.removeAt(index);
    });
  }

  Future<void> _autoDetect() async {
    if (!_isPlayerReady) return;
    if (_editingDeret.audioFilePath == null) return;

    // Step 1: Validate file format
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
            'Format .$extension tidak didukung. Gunakan: ${supportedFormats.join(', ')}',
          ),
        ),
      );
      return;
    }

    // Step 2: Validate file exists and is readable
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('[AUTO_DETECT] FAIL: File not found');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File audio tidak ditemukan')),
      );
      return;
    }

    final fileSize = await file.length();
    debugPrint('[AUTO_DETECT] File size: ${fileSize ~/ 1024} KB');

    if (fileSize > 100 * 1024 * 1024) {
      debugPrint('[AUTO_DETECT] FAIL: File too large');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File terlalu besar (maks 100MB)')),
      );
      return;
    }

    // Show loading dialog with cancel button
    if (!mounted) return;
    var loadingMessage = 'Mempersiapkan...';
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
                    child: const Text('Batal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // Step 3: Get duration
      loadingMessage = 'Memproses...';
      if (mounted) setState(() {});
      debugPrint('[AUTO_DETECT] Step 3: Getting duration...');

      final sw = Stopwatch()..start();
      final duration = await _playerController.getDuration().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Timeout membaca durasi'),
      );
      sw.stop();
      debugPrint(
        '[AUTO_DETECT] Duration: ${duration}ms (${sw.elapsedMilliseconds}ms)',
      );

      if (duration <= 0) {
        debugPrint('[AUTO_DETECT] FAIL: Invalid duration');
        throw Exception('Durasi audio tidak valid');
      }

      // Step 4: Adaptive sampling
      final noOfSamples = _adaptiveSampleCount(duration);
      debugPrint('[AUTO_DETECT] Adaptive samples: $noOfSamples');

      // Step 4b: Pre-check - try decode first 100 samples to validate file
      loadingMessage = 'Memvalidasi file audio...';
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
                  throw TimeoutException('Timeout validasi file (10 detik)'),
            );
      } catch (e) {
        debugPrint('[AUTO_DETECT] FAIL: Pre-check extraction error - $e');
        throw Exception(
          'Gagal membaca file audio. Pastikan file tidak corrupt dan format didukung.',
        );
      }

      if (preCheckData.isEmpty) {
        debugPrint('[AUTO_DETECT] FAIL: Pre-check returned empty data');
        throw Exception(
          'File audio tidak bisa di-decode. Coba convert ke WAV atau MP3 standar 128kbps CBR.',
        );
      }

      // Check if all samples are zero (decoder producing silence)
      final preCheckMax = preCheckData.reduce((a, b) => a > b ? a : b);
      final preCheckAvg =
          preCheckData.reduce((a, b) => a + b) / preCheckData.length;
      debugPrint(
        '[AUTO_DETECT] Pre-check: max=$preCheckMax, avg=${preCheckAvg.toStringAsFixed(4)}',
      );

      if (preCheckMax < 0.001 && preCheckAvg.abs() < 0.001) {
        debugPrint('[AUTO_DETECT] FAIL: All samples are zero - decoder issue');
        throw Exception(
          'File audio tidak kompatibel dengan decoder Android. '
          'Kemungkinan: VBR, corrupt, atau format tidak standar. '
          'Solusi: Convert ke WAV atau MP3 128kbps CBR.',
        );
      }

      // Step 5: Extract waveform data with timeout
      loadingMessage = 'Mengekstrak waveform ($noOfSamples samples)...';
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

      // Log sample data for debugging
      final maxVal = data.reduce((a, b) => a > b ? a : b);
      final minVal = data.reduce((a, b) => a < b ? a : b);
      final avgVal = data.reduce((a, b) => a + b) / data.length;
      debugPrint(
        '[AUTO_DETECT] Data stats: min=$minVal, max=$maxVal, avg=${avgVal.toStringAsFixed(4)}',
      );
      debugPrint('[AUTO_DETECT] First 10 samples: ${data.take(10).join(', ')}');

      // Step 6: Spike detection in isolate with timeout
      loadingMessage = 'Mendeteksi spike...';
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

      // Step 7: Update state
      if (!mounted) return;
      debugPrint('[AUTO_DETECT] Step 7: Updating UI state...');
      setState(() {
        _detectedSpikesCount = detectedTimes.length;
        for (int i = 0; i < detectedTimes.length; i++) {
          if (i < _editingDeret.words.length) {
            _editingDeret.words[i].timestampMs = detectedTimes[i];
          } else {
            _editingDeret.words.add(
              WordEntry(timestampMs: detectedTimes[i], word: "NEW"),
            );
            _wordControllers.add(TextEditingController(text: "NEW"));
          }
        }
        _editingDeret.isSynced = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil mendeteksi ${detectedTimes.length} spike'),
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
        ).showSnackBar(SnackBar(content: Text('Proses terlalu lama: $e')));
      }
    } catch (e, stackTrace) {
      debugPrint('[AUTO_DETECT] FAIL: $e');
      debugPrint('[AUTO_DETECT] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    // If already playing this word, pause it
    if (_currentPlayingIndex == index) {
      await _playerController.pausePlayer();
      await _durationSubscription?.cancel();
      _durationSubscription = null;
      setState(() {
        _currentPlayingIndex = -1;
      });
      return;
    }

    try {
      // Cancel old listener
      await _durationSubscription?.cancel();
      _durationSubscription = null;

      final state = _playerController.playerState;

      if (state == PlayerState.playing) {
        // Already playing - just seek to new position
        await _playerController.seekTo(timestamp);
      } else if (state == PlayerState.paused) {
        // Paused - resume then seek
        await _playerController.startPlayer();
        // Small delay to let play resume before seeking
        await Future.delayed(const Duration(milliseconds: 50));
        await _playerController.seekTo(timestamp);
      } else {
        // Stopped (initial state) - start playing then seek
        await _playerController.startPlayer();
        // Give audio pipeline time to initialize
        await Future.delayed(const Duration(milliseconds: 100));
        // Now seek to target position
        await _playerController.seekTo(timestamp);
      }

      setState(() {
        _currentPlayingIndex = index;
      });

      // Listen for position updates to track current word
      _durationSubscription = _playerController.onCurrentDurationChanged.listen(
        (duration) {
          if (!mounted) return;
          _updateCurrentPlayingIndex(duration);
        },
      );
    } catch (e) {
      debugPrint('Play error: $e');
      setState(() {
        _currentPlayingIndex = -1;
      });
    }
  }

  void _updateCurrentPlayingIndex(int currentMs) {
    if (!_isPlayerReady) return;
    if (_currentPlayingIndex < 0) return;

    // Find the word that corresponds to current position
    // The current playing word is the one with timestamp <= currentMs
    // but next word's timestamp hasn't been reached yet
    int newIndex = -1;
    for (int i = 0; i < _editingDeret.words.length; i++) {
      if (currentMs >= _editingDeret.words[i].timestampMs) {
        newIndex = i;
      }
    }

    // Also check if we've passed the next word's timestamp - if so, we're done with current
    if (newIndex != _currentPlayingIndex) {
      setState(() {
        _currentPlayingIndex = newIndex;
      });
    }

    // Check if playback stopped
    if (_playerController.playerState != PlayerState.playing &&
        _currentPlayingIndex >= 0) {
      // Check if we've reached the end by comparing with last word timestamp + some buffer
      if (_editingDeret.words.isNotEmpty &&
          currentMs >= _editingDeret.words.last.timestampMs + 500) {
        setState(() {
          _currentPlayingIndex = -1;
        });
      }
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
                    height: 60,
                    child: CustomPaint(
                      size: Size(double.infinity, 60),
                      painter: _ProgressPainter(
                        progress: progress,
                        wordTimestamps: _editingDeret.words
                            .map((w) => w.timestampMs)
                            .toList(),
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
    }

    Provider.of<WorkspaceProvider>(
      context,
      listen: false,
    ).updateDeret(_editingDeret);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _playerController.dispose();
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Deret ${widget.slotNumber}'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Column(
        children: [
          // Audio Section
          Container(
            width: double.infinity,
            color: Colors.blue.shade800,
            padding: const EdgeInsets.all(12),
            child: const Text(
              'PILIH AUDIO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _editingDeret.audioFilePath?.split('/').last ??
                        'Pilih file audio...',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAudioFile,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('Open'),
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
                          _playerController.playerState == PlayerState.playing
                              ? Icons.pause
                              : Icons.play_arrow,
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
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isDetecting ? 'Mendeteksi...' : 'Memproses...',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_isLoadingWaveform) const LinearProgressIndicator(),

          if (_detectedSpikesCount > 0 &&
              _detectedSpikesCount != _wordControllers.length)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peringatan: Spike ($_detectedSpikesCount) != Kata (${_wordControllers.length})',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(),
          // Word List Section
          Container(
            width: double.infinity,
            color: Colors.blue.shade800,
            padding: const EdgeInsets.all(12),
            child: const Text(
              'DAFTAR KATA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _wordControllers.length,
              itemBuilder: (context, index) {
                final isActive = _currentPlayingIndex == index;
                return Container(
                  color: isActive ? Colors.yellow.withAlpha(77) : null,
                  child: ListTile(
                    leading: Text('${index + 1}°'),
                    title: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            '${_editingDeret.words[index].timestampMs}ms',
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive ? Colors.orange : Colors.blueGrey,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _wordControllers[index],
                            decoration: const InputDecoration(
                              hintText: 'MAKS-8',
                            ),
                            maxLength: 8,
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isActive
                                ? Icons.pause_circle
                                : Icons.play_circle_outline,
                            color: isActive ? Colors.orange : Colors.green,
                            size: 28,
                          ),
                          onPressed: () async {
                            if (isActive) {
                              // Pause playback
                              await _playerController.pausePlayer();
                              await _durationSubscription?.cancel();
                              _durationSubscription = null;
                              setState(() {
                                _currentPlayingIndex = -1;
                              });
                            } else {
                              // Play from this word's timestamp
                              await _playFromWord(index);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
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
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kata'),
            ),
          ),
        ],
      ),
    );
  }
}

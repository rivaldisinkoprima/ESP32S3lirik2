import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../models/deret.dart';
import '../models/word_entry.dart';
import '../providers/workspace_provider.dart';
import '../services/spike_detector.dart';

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
      );

      _playerController.onPlayerStateChanged.listen((state) => setState(() {}));

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

    setState(() => _isDetecting = true);

    try {
      // Get waveform data from player
      final extractor = WaveformExtractionController();
      final data = await extractor.extractWaveformData(
        path: _editingDeret.audioFilePath!,
        noOfSamples: 5000,
      );

      int duration = await _playerController.getDuration();
      final detectedTimes = SpikeDetector.detect(
        waveformData: data,
        totalDurationMs: duration,
        minGapMs: 600,
      );

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }

  Future<void> _playFromWord(int index) async {
    if (!_isPlayerReady) return;
    if (index < 0 || index >= _editingDeret.words.length) return;

    final timestamp = _editingDeret.words[index].timestampMs;

    // Cancel previous subscription
    await _durationSubscription?.cancel();

    // Stop player completely first
    await _playerController.stopPlayer();
    await Future.delayed(const Duration(milliseconds: 100));

    // Seek to position
    await _playerController.seekTo(timestamp);
    await Future.delayed(const Duration(milliseconds: 50));

    // Start playing
    await _playerController.startPlayer();

    setState(() {
      _currentPlayingIndex = index;
    });

    // Listen for position updates to track current word
    _durationSubscription = _playerController.onCurrentDurationChanged.listen((
      duration,
    ) {
      if (!mounted) return;
      _updateCurrentPlayingIndex(duration);
    });
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

          if (_isPlayerReady) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  AudioFileWaveforms(
                    size: Size(MediaQuery.of(context).size.width, 80),
                    playerController: _playerController,
                    waveformType: WaveformType.fitWidth,
                    playerWaveStyle: PlayerWaveStyle(
                      fixedWaveColor: Colors.grey,
                      liveWaveColor: _currentPlayingIndex >= 0
                          ? Colors.yellow
                          : Colors.blueAccent,
                      seekLineColor: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Duration indicator
                  FutureBuilder<int>(
                    future: _playerController.getDuration(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final duration = snapshot.data!;
                      return StreamBuilder<int>(
                        stream: _playerController.onCurrentDurationChanged,
                        builder: (context, streamSnapshot) {
                          final current = streamSnapshot.data ?? 0;
                          return Text(
                            '${(current / 1000).toStringAsFixed(1)}s / ${(duration / 1000).toStringAsFixed(1)}s',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
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
                    if (_playerController.playerState == PlayerState.playing) {
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isDetecting ? 'Mendeteksi...' : 'Auto-Detect Spikes',
                  ),
                ),
              ],
            ),
          ] else if (_isLoadingWaveform)
            const LinearProgressIndicator(),

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
                            Icons.play_circle_outline,
                            color: isActive ? Colors.orange : Colors.green,
                          ),
                          onPressed: () => _playFromWord(index),
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

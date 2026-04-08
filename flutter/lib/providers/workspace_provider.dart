// Workspace Provider
//
// Fungsi:
// - Manage 10 slot deret (data lirik)
// - Simpan/update data ke local storage
// - Global offset: -500ms hingga +500ms (default 150ms)
// - Build bulk JSON untuk sync ke ESP32
// - Reset to default

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deret.dart';
import '../models/word_entry.dart';

class WorkspaceProvider with ChangeNotifier {
  final List<Deret> _derets = [];
  int _globalOffsetMs = 150;
  Deret? _lastDeletedDeret;
  int? _lastDeletedIndex;

  WorkspaceProvider() {
    _loadSettings();
    _initDefaultDerets();
  }

  List<Deret> get derets => _derets;
  int get globalOffsetMs => _globalOffsetMs;

  void _initDefaultDerets() {
    // PRD mentions default 10 derets.
    for (int i = 1; i <= 10; i++) {
      _derets.add(Deret(slotNumber: i));
    }
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _globalOffsetMs = prefs.getInt('global_offset_ms') ?? 150;
    notifyListeners();
  }

  Future<void> setGlobalOffset(int offset) async {
    _globalOffsetMs = offset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('global_offset_ms', offset);
    notifyListeners();
  }

  void updateDeret(Deret deret) {
    int index = _derets.indexWhere((d) => d.slotNumber == deret.slotNumber);
    if (index != -1) {
      _derets[index] = deret;
    } else {
      _derets.add(deret);
      _derets.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    }
    notifyListeners();
  }

  void addDeret() {
    int maxSlot = _derets.isEmpty
        ? 0
        : _derets.map((d) => d.slotNumber).reduce((a, b) => a > b ? a : b);
    final newDeret = Deret(slotNumber: maxSlot + 1);
    _derets.add(newDeret);
    _derets.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    notifyListeners();
  }

  void removeDeret(int slotNumber) {
    int index = _derets.indexWhere((d) => d.slotNumber == slotNumber);
    if (index != -1) {
      _lastDeletedDeret = _derets[index];
      _lastDeletedIndex = index;
      _derets.removeAt(index);
      notifyListeners();
    }
  }

  void restoreLastDeleted() {
    if (_lastDeletedDeret != null && _lastDeletedIndex != null) {
      _derets.insert(_lastDeletedIndex!, _lastDeletedDeret!);
      _derets.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
      _lastDeletedDeret = null;
      _lastDeletedIndex = null;
      notifyListeners();
    }
  }

  bool get canUndoDelete => _lastDeletedDeret != null;

  String buildBulkJson() {
    List<Map<String, dynamic>> payload = _derets
        .where((d) => d.isSynced && d.words.isNotEmpty)
        .map((d) => d.toJson(_globalOffsetMs))
        .toList();
    return jsonEncode(payload);
  }

  void resetToDefault() {
    _derets.clear();
    _initDefaultDerets();
  }

  /// Mengimpor data JSON mentah dari Supabase Cloud ke Workspace.
  /// Format data.json yang didukung:
  /// {"deret_1": ["SABUN","KUDA",...], "deret_2": [...], ...}
  ///
  /// [audioPaths]: opsional, map nomor deret ke path file audio lokal.
  ///
  /// Setelah import, kata-kata akan masuk ke workspace TANPA timestamp (t=0).
  /// Jika audio tersedia, user bisa langsung Auto-Detect tanpa pilih file lagi.
  void importFromCloudJson(String jsonString, {Map<int, String>? audioPaths}) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      int importedCount = 0;

      for (final entry in data.entries) {
        final key = entry.key.toLowerCase();
        if (!key.startsWith('deret_') || entry.value is! List) continue;

        final slotNum = int.tryParse(key.replaceAll('deret_', ''));
        if (slotNum == null || slotNum < 1 || slotNum > 10) continue;

        final words = (entry.value as List)
            .map((e) => e.toString().toUpperCase())
            .toList();

        final idx = _derets.indexWhere((d) => d.slotNumber == slotNum);
        if (idx == -1) continue;

        _derets[idx].displayTitle = 'Deret $slotNum';
        _derets[idx].words.clear();
        _derets[idx].audioFilePath = audioPaths?[slotNum]; // Set audio jika tersedia
        _derets[idx].isSynced = false;     // Belum siap — perlu Auto-Detect dulu

        for (final word in words) {
          final truncated = word.length > 8 ? word.substring(0, 8) : word;
          _derets[idx].words.add(WordEntry(timestampMs: 0, word: truncated));
        }

        importedCount++;
        debugPrint('[CloudUpdate] Imported deret_$slotNum: ${words.length} kata');
      }

      notifyListeners();
      debugPrint('[CloudUpdate] Total $importedCount deret berhasil diimpor dari cloud.');
    } catch (e) {
      debugPrint('[CloudUpdate] Error parsing cloud JSON: $e');
    }
  }
}

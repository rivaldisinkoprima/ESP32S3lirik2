// Workspace Provider
//
// Fungsi:
// - Manage slot deret dinamis (data lirik) — tidak terbatas 10
// - Simpan/update data ke local storage (SharedPreferences)
// - Global offset: -500ms hingga +500ms (default 150ms)
// - Build bulk JSON untuk sync ke ESP32
// - Reset to default
// - Persistensi workspace otomatis (Fase 9)

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
  bool _initialized = false;

  WorkspaceProvider() {
    _initAsync();
  }

  /// Inisialisasi async: load settings + restore workspace dari SharedPreferences
  Future<void> _initAsync() async {
    await _loadSettings();
    await _loadDerets();
    _initialized = true;
  }

  List<Deret> get derets => _derets;
  int get globalOffsetMs => _globalOffsetMs;
  bool get isInitialized => _initialized;

  void _initDefaultDerets() {
    // Default 10 deret saat pertama kali, tapi bisa ditambah/kurangi
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
    _saveDerets(); // ★ Persist
    notifyListeners();
  }

  void addDeret() {
    int maxSlot = _derets.isEmpty
        ? 0
        : _derets.map((d) => d.slotNumber).reduce((a, b) => a > b ? a : b);
    final newDeret = Deret(slotNumber: maxSlot + 1);
    _derets.add(newDeret);
    _derets.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    _saveDerets(); // ★ Persist
    notifyListeners();
  }

  /// Membuat deret pada slot nomor tertentu (dipakai saat bulk import auto-create).
  /// Tidak melakukan apa-apa jika slot sudah ada.
  void addDeretWithSlot(int slot) {
    if (_derets.any((d) => d.slotNumber == slot)) return; // Sudah ada, skip
    final newDeret = Deret(slotNumber: slot);
    _derets.add(newDeret);
    _derets.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    _saveDerets(); // ★ Persist
    notifyListeners();
  }

  void removeDeret(int slotNumber) {
    int index = _derets.indexWhere((d) => d.slotNumber == slotNumber);
    if (index != -1) {
      _lastDeletedDeret = _derets[index];
      _lastDeletedIndex = index;
      _derets.removeAt(index);
      _saveDerets(); // ★ Persist
      notifyListeners();
    }
  }

  void restoreLastDeleted() {
    if (_lastDeletedDeret != null && _lastDeletedIndex != null) {
      _derets.insert(_lastDeletedIndex!, _lastDeletedDeret!);
      _derets.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
      _lastDeletedDeret = null;
      _lastDeletedIndex = null;
      _saveDerets(); // ★ Persist
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
    _saveDerets(); // ★ Persist
  }

  // ─── Fase 9: Persistensi Workspace ke SharedPreferences ─────────────────

  /// Simpan state deret ke SharedPreferences setiap kali berubah.
  Future<void> _saveDerets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _derets.map((d) => {
      'slot': d.slotNumber,
      'title': d.displayTitle,
      'synced': d.isSynced,
      'audioPath': d.audioFilePath,
      'words': d.words.map((w) => {
        't': w.timestampMs,
        'w': w.word,
      }).toList(),
    }).toList();
    await prefs.setString('saved_derets', jsonEncode(jsonList));
    debugPrint('[Workspace] Saved ${_derets.length} derets to SharedPreferences');
  }

  /// Restore workspace saat startup. Jika tidak ada data tersimpan, pakai default 10 slot.
  Future<void> _loadDerets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_derets');
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List;
        _derets.clear();
        for (final item in list) {
          final deret = Deret(
            slotNumber: item['slot'] as int,
            displayTitle: item['title'] as String?,
            isSynced: item['synced'] as bool? ?? false,
            audioFilePath: item['audioPath'] as String?,
          );
          // Restore words jika ada
          if (item['words'] != null && item['words'] is List) {
            for (final w in item['words']) {
              deret.words.add(WordEntry(
                timestampMs: w['t'] as int? ?? 0,
                word: w['w'] as String? ?? '',
              ));
            }
          }
          _derets.add(deret);
        }
        _derets.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
        debugPrint('[Workspace] Restored ${_derets.length} derets from SharedPreferences');
        notifyListeners();
        return; // Sukses restore, jangan init default
      } catch (e) {
        debugPrint('[Workspace] Error restoring derets: $e');
      }
    }
    // Pertama kali: 10 slot default
    _initDefaultDerets();
  }

  // ─── Fase 7b: Import Cloud Dinamis (maks 50 slot + auto-expand) ─────────

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
        // ★ Fase 7b: Batas dinaikkan dari 10 → 50
        if (slotNum == null || slotNum < 1 || slotNum > 50) continue;

        final words = (entry.value as List)
            .map((e) => e.toString().toUpperCase())
            .toList();

        // ★ Auto-expand list jika slot baru lebih tinggi dari yang ada
        while (_derets.length < slotNum) {
          _derets.add(Deret(slotNumber: _derets.length + 1));
        }

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

      _saveDerets(); // ★ Persist setelah import
      notifyListeners();
      debugPrint('[CloudUpdate] Total $importedCount deret berhasil diimpor dari cloud.');
    } catch (e) {
      debugPrint('[CloudUpdate] Error parsing cloud JSON: $e');
    }
  }
}

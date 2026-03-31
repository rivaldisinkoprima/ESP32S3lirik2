import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deret.dart';

class WorkspaceProvider with ChangeNotifier {
  final List<Deret> _derets = [];
  int _globalOffsetMs = 150; // Default as per PRD

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
}

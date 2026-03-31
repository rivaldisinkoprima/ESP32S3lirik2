import 'word_entry.dart';

class Deret {
  int slotNumber;
  String? audioFilePath;
  List<WordEntry> words;
  bool isSynced;
  String? displayTitle;

  Deret({
    required this.slotNumber,
    this.audioFilePath,
    List<WordEntry>? words,
    this.isSynced = false,
    this.displayTitle,
  }) : words = words ?? [];

  Map<String, dynamic> toJson(int offsetMs) {
    return {
      'd': slotNumber,
      'name': displayTitle ?? 'Deret $slotNumber',
      'v': words.map((w) => {
        't': w.timestampMs + offsetMs,
        'w': w.word,
      }).toList(),
    };
  }
}

// WordEntry Model
//
// Struktur data untuk satu kata:
// - timestampMs: Waktu muncul dalam milidetik
// - word: Teks kata (maks 8 karakter)

class WordEntry {
  int timestampMs;
  String word;

  WordEntry({required this.timestampMs, required this.word});

  Map<String, dynamic> toJson() => {'t': timestampMs, 'w': word};

  factory WordEntry.fromJson(Map<String, dynamic> json) =>
      WordEntry(timestampMs: json['t'], word: json['w']);
}

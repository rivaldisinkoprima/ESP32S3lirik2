// Spike Detector Service
//
// Fungsi:
// - Deteksi onset/timing kata dari waveform audio
// - Algoritma: cari amplitude > threshold dengan minGapMs antar spike
//
// Parameter:
// - waveformData: List amplitude (0.0-1.0)
// - totalDurationMs: Durasi total audio
// - threshold: Batas amplitude untuk "loud" (default 0.03 untuk audio bersih)
// - minGapMs: Jarak minimum antar kata (default 600ms)

class SpikeDetector {
  /// Detects onset timestamps (ms) based on waveform data.
  ///
  /// [waveformData] is the list of amplitudes (0.0 to 1.0).
  /// [totalDurationMs] is the duration of the audio in milliseconds.
  /// [threshold] is the volume threshold to define "loud" (default 0.03).
  /// [minGapMs] is the minimum silent gap required between words (default 600ms).
  static List<int> detect({
    required List<double> waveformData,
    required int totalDurationMs,
    double threshold = 0.03,
    int minGapMs = 600,
  }) {
    if (waveformData.isEmpty || totalDurationMs <= 0) return [];

    List<int> timestamps = [];
    int samplesCount = waveformData.length;
    double msPerSample = totalDurationMs / samplesCount;

    // Pre-process: smooth the waveform with a small moving average
    // This helps catch the true onset of words that start quietly
    List<double> smoothed = List<double>.filled(samplesCount, 0.0);
    int windowSize = 3;
    for (int i = 0; i < samplesCount; i++) {
      double sum = 0.0;
      int count = 0;
      for (int j = i - windowSize; j <= i + windowSize; j++) {
        if (j >= 0 && j < samplesCount) {
          sum += waveformData[j].abs();
          count++;
        }
      }
      smoothed[i] = sum / count;
    }

    bool inSpike = false;
    int lastSpikeEndIndex = -((minGapMs / msPerSample).round());

    for (int i = 0; i < samplesCount; i++) {
      double amplitude = smoothed[i];

      if (amplitude > threshold) {
        if (!inSpike) {
          // New spike detected - this is the onset
          int currentTimeMs = (i * msPerSample).toInt();
          int gapSinceLast =
              currentTimeMs - (lastSpikeEndIndex * msPerSample).toInt();

          if (gapSinceLast >= minGapMs) {
            timestamps.add(currentTimeMs);
            inSpike = true;
          }
        }
      } else {
        if (inSpike) {
          inSpike = false;
          lastSpikeEndIndex = i;
        }
      }
    }

    return timestamps;
  }
}

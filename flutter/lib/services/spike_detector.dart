class SpikeDetector {
  /// Detects onset timestamps (ms) based on waveform data.
  /// 
  /// [waveformData] is the list of amplitudes (0.0 to 1.0).
  /// [totalDurationMs] is the duration of the audio in milliseconds.
  /// [threshold] is the volume threshold to define "loud" (default 0.1).
  /// [minGapMs] is the minimum silent gap required between words (default 800ms).
  static List<int> detect({
    required List<double> waveformData,
    required int totalDurationMs,
    double threshold = 0.1,
    int minGapMs = 800,
  }) {
    if (waveformData.isEmpty || totalDurationMs <= 0) return [];

    List<int> timestamps = [];
    int samplesCount = waveformData.length;
    double msPerSample = totalDurationMs / samplesCount;

    bool inSpike = false;
    int lastSpikeEndIndex = -minGapMs; // Start before audio

    for (int i = 0; i < samplesCount; i++) {
        double amplitude = waveformData[i].abs();
        
        if (amplitude > threshold) {
            if (!inSpike) {
                // Potential new spike
                int currentTimeMs = (i * msPerSample).toInt();
                int gapSinceLast = currentTimeMs - (lastSpikeEndIndex * msPerSample).toInt();

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

import 'dart:math';

class BeatInfo {
  final double time;
  final double intensity; // 0.0 to 1.0
  const BeatInfo({required this.time, required this.intensity});
}

class AudioProcessor {
  /// Mock function to simulate beat detection from an audio file.
  /// In a real scenario, this would use FFT (Fast Fourier Transform) to find peaks.
  static List<BeatInfo> detectBeats(double durationSeconds, {double bpm = 120}) {
    final List<BeatInfo> beats = [];
    final double interval = 60 / bpm; // seconds per beat

    for (double t = 0; t < durationSeconds; t += interval) {
      // Add some randomness to intensity to simulate real music
      beats.add(BeatInfo(
        time: t,
        intensity: 0.6 + (Random().nextDouble() * 0.4),
      ));
    }

    return beats;
  }
}

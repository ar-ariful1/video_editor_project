// lib/features/editor/widgets/waveform_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app_theme.dart';

class WaveformData {
  final List<double> samples; // normalized 0.0–1.0 amplitudes
  final double duration;
  const WaveformData({required this.samples, required this.duration});

  factory WaveformData.generate(double duration, {int resolution = 200}) {
    final rng = math.Random(42);
    final samples = List.generate(resolution, (i) {
      final envelope = math.sin(i / resolution * math.pi);
      return envelope * (0.3 + rng.nextDouble() * 0.7);
    });
    return WaveformData(samples: samples, duration: duration);
  }
}

class WaveformWidget extends StatelessWidget {
  final WaveformData? data;
  final double currentTime;
  final double totalDuration;
  final Color waveColor;
  final Color playedColor;
  final void Function(double time)? onSeek;

  const WaveformWidget({
    super.key,
    this.data,
    required this.currentTime,
    required this.totalDuration,
    this.waveColor = const Color(0xFF7C6EF7),
    this.playedColor = const Color(0xFF4ECDC4),
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        if (onSeek == null || totalDuration <= 0) return;
        final frac = d.localPosition.dx / context.size!.width;
        onSeek!(frac.clamp(0, 1) * totalDuration);
      },
      child: CustomPaint(
        painter: _WaveformPainter(
          data: data ?? WaveformData.generate(totalDuration),
          progress:
              totalDuration > 0 ? (currentTime / totalDuration).clamp(0, 1) : 0,
          waveColor: waveColor,
          playedColor: playedColor,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final WaveformData data;
  final double progress;
  final Color waveColor, playedColor;

  const _WaveformPainter(
      {required this.data,
      required this.progress,
      required this.waveColor,
      required this.playedColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.samples.isEmpty) return;

    final barWidth = size.width / data.samples.length;
    final midY = size.height / 2;
    final playedX = progress * size.width;

    final unplayedPaint = Paint()
      ..color = waveColor.withValues(alpha: 0.5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (barWidth - 1).clamp(1, 3);
    final playedPaint = Paint()
      ..color = playedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (barWidth - 1).clamp(1, 3);

    for (int i = 0; i < data.samples.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amp = data.samples[i];
      final h = amp * midY * 0.95;

      final paint = x <= playedX ? playedPaint : unplayedPaint;
      canvas.drawLine(Offset(x, midY - h), Offset(x, midY + h), paint);
    }

    // Playhead
    final pPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(playedX, 0), Offset(playedX, size.height), pPaint);
    canvas.drawCircle(
        Offset(playedX, size.height / 2), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

// ── Beat Marker Painter ──────────────────────────────────────────────────────

class BeatMarkerPainter extends CustomPainter {
  final List<double> beatTimes;
  final List<double> downbeatTimes;
  final double totalDuration;
  final double zoom;
  final double scrollOffset;

  const BeatMarkerPainter(
      {required this.beatTimes,
      required this.downbeatTimes,
      required this.totalDuration,
      required this.zoom,
      required this.scrollOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final beatPaint = Paint()
      ..color = const Color(0xFF4ECDC480)
      ..strokeWidth = 1;
    final downbeatPaint = Paint()
      ..color = const Color(0xFFF7C948CC)
      ..strokeWidth = 2;

    for (final t in beatTimes) {
      final x = t * zoom - scrollOffset;
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), beatPaint);
    }

    for (final t in downbeatTimes) {
      final x = t * zoom - scrollOffset;
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), downbeatPaint);
      final tp = TextPainter(
          text: TextSpan(
              text: '♩',
              style: const TextStyle(color: Color(0xFFF7C948), fontSize: 10)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x + 2, 2));
    }
  }

  @override
  bool shouldRepaint(BeatMarkerPainter old) => old.scrollOffset != scrollOffset;
}

// ── Audio Waveform in Timeline Clip ─────────────────────────────────────────

class ClipWaveformWidget extends StatelessWidget {
  final String clipId;
  final double clipDuration;
  final Color color;

  const ClipWaveformWidget(
      {super.key,
      required this.clipId,
      required this.clipDuration,
      this.color = AppTheme.accent2});

  @override
  Widget build(BuildContext context) {
    // Generate deterministic waveform from clip ID hash
    final seed = clipId.codeUnits.fold(0, (a, b) => a + b);
    final data = WaveformData.generate(clipDuration, resolution: 80);

    return CustomPaint(
      painter: _WaveformPainter(
        data: data,
        progress: 0,
        waveColor: color,
        playedColor: color,
      ),
    );
  }
}


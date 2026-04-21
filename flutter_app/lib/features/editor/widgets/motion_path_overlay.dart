import 'package:flutter/material.dart';
import '../../../core/models/video_project.dart';

class MotionPathOverlay extends StatelessWidget {
  final Clip clip;
  final Resolution resolution;
  final double currentTime;

  const MotionPathOverlay({
    super.key,
    required this.clip,
    required this.resolution,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    // Get all unique keyframe times for position
    final xKeyframes = clip.keyframes.where((k) => k.property == 'x').toList();
    final yKeyframes = clip.keyframes.where((k) => k.property == 'y').toList();

    if (xKeyframes.isEmpty && yKeyframes.isEmpty) {
      return const SizedBox.shrink();
    }

    final allTimes = <double>{};
    for (final k in xKeyframes) {
      allTimes.add(k.time);
    }
    for (final k in yKeyframes) {
      allTimes.add(k.time);
    }

    final sortedTimes = allTimes.toList()..sort();

    // We also want to include the current time to show where we are on the path
    final localTime = (currentTime - clip.startTime).clamp(0.0, clip.duration);

    return IgnorePointer(
      child: CustomPaint(
        painter: MotionPathPainter(
          clip: clip,
          sortedTimes: sortedTimes,
          localTime: localTime,
          resolution: resolution,
        ),
        size: Size(resolution.width.toDouble(), resolution.height.toDouble()),
      ),
    );
  }
}

class MotionPathPainter extends CustomPainter {
  final Clip clip;
  final List<double> sortedTimes;
  final double localTime;
  final Resolution resolution;

  MotionPathPainter({
    required this.clip,
    required this.sortedTimes,
    required this.localTime,
    required this.resolution,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sortedTimes.isEmpty) return;

    final pathPaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final currentPosPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    final path = Path();
    final List<Offset> points = [];

    // Sample points along the path for smooth curves if using easing
    // For now, we connect keyframes with lines or curves based on interpolation

    for (int i = 0; i < sortedTimes.length; i++) {
      final t = sortedTimes[i];
      final x = clip.getKeyframeValue('x', t) ?? 0.0;
      final y = clip.getKeyframeValue('y', t) ?? 0.0;

      final offset = Offset(x * size.width, y * size.height);
      points.add(offset);

      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        // Simple linear path for visualization of segments
        path.lineTo(offset.dx, offset.dy);
      }
    }

    // Draw the path
    canvas.drawPath(path, pathPaint);

    // Draw keyframe dots
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(point, 4, pathPaint..style = PaintingStyle.stroke..color = Colors.blue);
    }

    // Draw current position on path
    final curX = clip.getKeyframeValue('x', localTime) ?? 0.0;
    final curY = clip.getKeyframeValue('y', localTime) ?? 0.0;
    final curOffset = Offset(curX * size.width, curY * size.height);

    canvas.drawCircle(curOffset, 6, currentPosPaint);
    canvas.drawCircle(curOffset, 6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant MotionPathPainter oldDelegate) {
    return oldDelegate.clip != clip ||
           oldDelegate.localTime != localTime ||
           oldDelegate.resolution != resolution;
  }
}

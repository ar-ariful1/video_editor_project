import 'dart:math';

enum EasingType { linear, bezier, hold }

class Keyframe {
  final double timeUs;
  final double value;
  final EasingType easing;
  final double cp1x, cp1y, cp2x, cp2y;

  Keyframe({
    required this.timeUs,
    required this.value,
    this.easing = EasingType.linear,
    this.cp1x = 0.42,
    this.cp1y = 0.0,
    this.cp2x = 0.58,
    this.cp2y = 1.0,
  });
}

class KeyframeEngine {
  double evaluate(List<Keyframe> keyframes, double currentTimeUs) {
    if (keyframes.isEmpty) return 0.0;
    if (keyframes.length == 1 || currentTimeUs <= keyframes.first.timeUs) {
      return keyframes.first.value;
    }
    if (currentTimeUs >= keyframes.last.timeUs) {
      return keyframes.last.value;
    }

    // Find the current segment
    int nextIdx = keyframes.indexWhere((k) => k.timeUs > currentTimeUs);
    final prev = keyframes[nextIdx - 1];
    final next = keyframes[nextIdx];

    double t = (currentTimeUs - prev.timeUs) / (next.timeUs - prev.timeUs);

    if (next.easing == EasingType.bezier) {
      return _interpolateBezier(prev.value, next.value, t, next.cp1x, next.cp1y, next.cp2x, next.cp2y);
    } else if (next.easing == EasingType.hold) {
      return prev.value;
    }

    return prev.value + (next.value - prev.value) * t;
  }

  double _interpolateBezier(double start, double end, double t, double x1, double y1, double x2, double y2) {
    // Cubic Bezier Ease-in-out calculation
    // Simplified for Dart; production uses Newton-Raphson as in C++
    double factor = pow(1 - t, 3) * 0 + 3 * pow(1 - t, 2) * t * x1 + 3 * (1 - t) * pow(t, 2) * x2 + pow(t, 3) * 1;
    return start + (end - start) * factor;
  }
}

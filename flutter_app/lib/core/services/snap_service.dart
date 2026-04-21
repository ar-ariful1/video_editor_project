// lib/core/services/snap_service.dart
import '../models/video_project.dart';

class SnapResult {
  final double snappedTime;
  final bool didSnap;
  final SnapType? snapType;
  const SnapResult(
      {required this.snappedTime, required this.didSnap, this.snapType});
}

enum SnapType { clipStart, clipEnd, playhead, beat, gridLine }

class SnapService {
  static const double _snapRadius = 0.15; // seconds
  bool enabled = true;
  bool snapToClips = true;
  bool snapToBeats = true;
  bool snapToGrid = true;
  double gridInterval = 1.0; // seconds

  List<double> _beatTimes = [];
  void setBeatTimes(List<double> beats) => _beatTimes = beats;

  SnapResult snap({
    required double time,
    required VideoProject project,
    required double playheadTime,
    String? excludeClipId,
  }) {
    if (!enabled) return SnapResult(snappedTime: time, didSnap: false);

    double best = time;
    double minDist = _snapRadius;
    SnapType? bestType;

    // Snap to clip edges
    if (snapToClips) {
      for (final track in project.tracks) {
        for (final clip in track.clips) {
          if (clip.id == excludeClipId) continue;
          for (final t in [clip.startTime, clip.endTime]) {
            final dist = (t - time).abs();
            if (dist < minDist) {
              minDist = dist;
              best = t;
              bestType =
                  t == clip.startTime ? SnapType.clipStart : SnapType.clipEnd;
            }
          }
        }
      }
    }

    // Snap to playhead
    final pdist = (playheadTime - time).abs();
    if (pdist < minDist) {
      minDist = pdist;
      best = playheadTime;
      bestType = SnapType.playhead;
    }

    // Snap to beats
    if (snapToBeats) {
      for (final b in _beatTimes) {
        final d = (b - time).abs();
        if (d < minDist) {
          minDist = d;
          best = b;
          bestType = SnapType.beat;
        }
      }
    }

    // Snap to grid
    if (snapToGrid) {
      final nearest = (time / gridInterval).round() * gridInterval;
      final d = (nearest - time).abs();
      if (d < minDist) {
        minDist = d;
        best = nearest;
        bestType = SnapType.gridLine;
      }
    }

    return SnapResult(
        snappedTime: best, didSnap: bestType != null, snapType: bestType);
  }
}

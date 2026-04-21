import '../models/video_project.dart';

/// TimelineResolver - The core engine that resolves the state of the project 
/// at any given point in time. This is the "Single Source of Truth".
class TimelineResolver {
  
  /// Resolves all active clips and their properties at a specific [time].
  static List<ResolvedClip> resolve(VideoProject project, double time) {
    final List<ResolvedClip> resolved = [];
    
    // Sort tracks by zIndex to ensure correct rendering order
    final sortedTracks = List<Track>.from(project.tracks)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final track in sortedTracks) {
      if (track.isMuted) continue;

      for (final clip in track.clips) {
        if (time >= clip.startTime && time <= clip.endTime) {
          final localTime = time - clip.startTime;
          
          // Calculate animated properties based on keyframes
          final props = ResolvedProperties(
            x: clip.getKeyframeValue('x', localTime) ?? clip.transform.x,
            y: clip.getKeyframeValue('y', localTime) ?? clip.transform.y,
            scaleX: clip.getKeyframeValue('scaleX', localTime) ?? clip.transform.scaleX,
            scaleY: clip.getKeyframeValue('scaleY', localTime) ?? clip.transform.scaleY,
            rotation: clip.getKeyframeValue('rotation', localTime) ?? clip.transform.rotation,
            opacity: clip.getKeyframeValue('opacity', localTime) ?? clip.opacity,
            volume: clip.volume,
            brightness: clip.getKeyframeValue('brightness', localTime) ?? clip.colorGrade?.brightness ?? 0.0,
            contrast: clip.getKeyframeValue('contrast', localTime) ?? clip.colorGrade?.contrast ?? 1.0,
            saturation: clip.getKeyframeValue('saturation', localTime) ?? clip.colorGrade?.saturation ?? 1.0,
            effectiveMediaTime: (localTime * clip.speed) + clip.trimStart,
          );

          // Handle adjustment layers
          List<AdjustmentLayer> activeAdjustments = [];
          if (clip.isAdjustmentLayer) {
             // In a real engine, we apply this to everything below it
          }

          resolved.add(ResolvedClip(
            clip: clip,
            track: track,
            props: props,
            appliedAdjustments: activeAdjustments,
          ));
        }
      }
    }
    
    return resolved;
  }

  /// Converts the entire project into a Map structure that the Native Engine understands.
  static Map<String, dynamic> exportToNative(VideoProject project) {
    return {
      'id': project.id,
      'duration': project.duration,
      'width': project.resolution.width,
      'height': project.resolution.height,
      'quality': 'STANDARD',
      'tracks': project.tracks.map((track) => {
        'id': track.id,
        'type': track.type.name,
        'zIndex': track.zIndex,
        'clips': track.clips.map((clip) => clip.toJson()).toList(),
      }).toList(),
    };
  }
}

class ResolvedClip {
  final Clip clip;
  final Track track;
  final ResolvedProperties props;
  final List<AdjustmentLayer> appliedAdjustments;

  ResolvedClip({
    required this.clip,
    required this.track,
    required this.props,
    this.appliedAdjustments = const [],
  });
}

class ResolvedProperties {
  final double x;
  final double y;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double opacity;
  final double volume;
  final double brightness;
  final double contrast;
  final double saturation;
  final double effectiveMediaTime;

  ResolvedProperties({
    required this.x,
    required this.y,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
    required this.opacity,
    required this.volume,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.effectiveMediaTime,
  });
}

// lib/core/models/advanced_features.dart
// Professional video editor features - Chroma Key, Masking, Audio Keyframes, etc.

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart'; 
import 'video_project.dart';

const _uuid = Uuid();

// ============================================================================
// 1. CHROMA KEY (Green Screen)
// ============================================================================

enum ChromaKeyColor {
  green,
  blue,
  red,
  custom,
}

class ChromaKey extends Equatable {
  final String id;
  final bool enabled;
  final ChromaKeyColor keyColor;
  final Color customColor;
  final double similarity;      // 0.0 to 1.0 - how similar colors to remove
  final double smoothness;      // 0.0 to 1.0 - edge smoothness
  final double spillSuppression; // 0.0 to 1.0 - remove green spill
  final double edgeFeather;      // 0.0 to 5.0 - feather edges
  final bool invert;             // invert selection

  const ChromaKey({
    required this.id,
    this.enabled = true,
    this.keyColor = ChromaKeyColor.green,
    this.customColor = Colors.green,
    this.similarity = 0.4,
    this.smoothness = 0.3,
    this.spillSuppression = 0.5,
    this.edgeFeather = 1.0,
    this.invert = false,
  });

  factory ChromaKey.create() => ChromaKey(
    id: _uuid.v4(),
  );

  ChromaKey copyWith({
    String? id,
    bool? enabled,
    ChromaKeyColor? keyColor,
    Color? customColor,
    double? similarity,
    double? smoothness,
    double? spillSuppression,
    double? edgeFeather,
    bool? invert,
  }) => ChromaKey(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    keyColor: keyColor ?? this.keyColor,
    customColor: customColor ?? this.customColor,
    similarity: similarity ?? this.similarity,
    smoothness: smoothness ?? this.smoothness,
    spillSuppression: spillSuppression ?? this.spillSuppression,
    edgeFeather: edgeFeather ?? this.edgeFeather,
    invert: invert ?? this.invert,
  );

  // Get Native Engine filter config
  Map<String, dynamic> toNativeFilter() {
    Color color;
    switch (keyColor) {
      case ChromaKeyColor.green:
        color = Colors.green;
        break;
      case ChromaKeyColor.blue:
        color = Colors.blue;
        break;
      case ChromaKeyColor.red:
        color = Colors.red;
        break;
      case ChromaKeyColor.custom:
        color = customColor;
        break;
    }
    
    return {
      'type': 'chromakey',
      'color': color.toARGB32(),
      'similarity': similarity,
      'smoothness': smoothness,
      'spillSuppression': spillSuppression,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'keyColor': keyColor.name,
    'customColor': customColor.toARGB32(),
    'similarity': similarity,
    'smoothness': smoothness,
    'spillSuppression': spillSuppression,
    'edgeFeather': edgeFeather,
    'invert': invert,
  };

  factory ChromaKey.fromJson(Map<String, dynamic> j) => ChromaKey(
    id: j['id'],
    enabled: j['enabled'] ?? true,
    keyColor: ChromaKeyColor.values.byName(j['keyColor'] ?? 'green'),
    customColor: Color(j['customColor'] ?? 0xFF00FF00),
    similarity: j['similarity'] ?? 0.4,
    smoothness: j['smoothness'] ?? 0.3,
    spillSuppression: j['spillSuppression'] ?? 0.5,
    edgeFeather: j['edgeFeather'] ?? 1.0,
    invert: j['invert'] ?? false,
  );

  @override
  List<Object?> get props => [id, enabled, keyColor, similarity, smoothness];
}

// ============================================================================
// 2. MASKING SYSTEM
// ============================================================================

enum MaskType {
  none,
  circle,
  linear,
  rectangle,
  heart,
  star,
  text,
  custom,
}

class Mask extends Equatable {
  final String id;
  final bool enabled;
  final MaskType type;
  final Rect bounds;           // position and size
  final double feather;        // edge blur
  final double opacity;        // mask opacity
  final bool inverted;         // invert mask
  final String? text;          // for text mask
  final List<Offset>? points;  // for custom polygon mask

  const Mask({
    required this.id,
    this.enabled = true,
    this.type = MaskType.none,
    this.bounds = const Rect.fromLTWH(0, 0, 1, 1),
    this.feather = 0,
    this.opacity = 1.0,
    this.inverted = false,
    this.text,
    this.points,
  });

  factory Mask.create({MaskType type = MaskType.circle}) => Mask(
    id: _uuid.v4(),
    type: type,
    bounds: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
  );

  Mask copyWith({
    String? id,
    bool? enabled,
    MaskType? type,
    Rect? bounds,
    double? feather,
    double? opacity,
    bool? inverted,
    String? text,
    List<Offset>? points,
  }) => Mask(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    type: type ?? this.type,
    bounds: bounds ?? this.bounds,
    feather: feather ?? this.feather,
    opacity: opacity ?? this.opacity,
    inverted: inverted ?? this.inverted,
    text: text ?? this.text,
    points: points ?? this.points,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'type': type.name,
    'bounds': {'left': bounds.left, 'top': bounds.top, 'width': bounds.width, 'height': bounds.height},
    'feather': feather,
    'opacity': opacity,
    'inverted': inverted,
    'text': text,
    'points': points?.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
  };

  factory Mask.fromJson(Map<String, dynamic> j) => Mask(
    id: j['id'],
    enabled: j['enabled'] ?? true,
    type: MaskType.values.byName(j['type'] ?? 'none'),
    bounds: j['bounds'] != null 
        ? Rect.fromLTWH(j['bounds']['left'], j['bounds']['top'], j['bounds']['width'], j['bounds']['height'])
        : const Rect.fromLTWH(0, 0, 1, 1),
    feather: j['feather'] ?? 0,
    opacity: j['opacity'] ?? 1.0,
    inverted: j['inverted'] ?? false,
    text: j['text'],
    points: j['points'] != null 
        ? (j['points'] as List).map((p) => Offset(p['dx'], p['dy'])).toList()
        : null,
  );

  @override
  List<Object?> get props => [id, enabled, type, bounds, feather];
}

// ============================================================================
// 3. AUDIO KEYFRAMES (Volume Envelope)
// ============================================================================

class AudioKeyframe extends Equatable {
  final String id;
  final double time;      // seconds
  final double volume;    // 0.0 to 1.0
  final EasingType easing;

  const AudioKeyframe({
    required this.id,
    required this.time,
    required this.volume,
    this.easing = EasingType.linear,
  });

  factory AudioKeyframe.create({required double time, required double volume}) => AudioKeyframe(
    id: _uuid.v4(),
    time: time,
    volume: volume,
  );

  AudioKeyframe copyWith({double? time, double? volume}) => AudioKeyframe(
    id: id,
    time: time ?? this.time,
    volume: volume ?? this.volume,
    easing: easing,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'volume': volume,
    'easing': easing.name,
  };

  factory AudioKeyframe.fromJson(Map<String, dynamic> j) => AudioKeyframe(
    id: j['id'],
    time: j['time'],
    volume: j['volume'],
    easing: EasingType.values.byName(j['easing'] ?? 'linear'),
  );

  @override
  List<Object?> get props => [id, time, volume];
}

class AudioEnvelope extends Equatable {
  final List<AudioKeyframe> keyframes;

  const AudioEnvelope({this.keyframes = const []});

  double getVolumeAtTime(double time) {
    if (keyframes.isEmpty) return 1.0;
    if (keyframes.length == 1) return keyframes.first.volume;
    
    // Find surrounding keyframes
    AudioKeyframe? prev;
    AudioKeyframe? next;
    
    for (final kf in keyframes) {
      if (kf.time <= time) prev = kf;
      if (kf.time >= time && next == null) next = kf;
    }
    
    if (prev == null) return keyframes.first.volume;
    if (next == null) return prev.volume;
    if (prev.time == next.time) return prev.volume;
    
    final t = (time - prev.time) / (next.time - prev.time);
    return prev.volume + (next.volume - prev.volume) * t;
  }

  Map<String, dynamic> toJson() => {
    'keyframes': keyframes.map((k) => k.toJson()).toList(),
  };

  factory AudioEnvelope.fromJson(Map<String, dynamic> j) => AudioEnvelope(
    keyframes: (j['keyframes'] as List? ?? [])
        .map((k) => AudioKeyframe.fromJson(k))
        .toList(),
  );

  @override
  List<Object?> get props => [keyframes];
}

// ============================================================================
// 4. COLOR CURVES & WHEELS
// ============================================================================

class ColorPoint extends Equatable {
  final double x;  // input (0-1)
  final double y;  // output (0-1)

  const ColorPoint({required this.x, required this.y});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory ColorPoint.fromJson(Map<String, dynamic> j) => ColorPoint(x: j['x'], y: j['y']);

  @override
  List<Object?> get props => [x, y];
}

class ColorCurve extends Equatable {
  final String channel; // 'rgb', 'red', 'green', 'blue', 'hue', 'saturation', 'luminance'
  final List<ColorPoint> points;

  const ColorCurve({required this.channel, this.points = const []});

  double evaluate(double input) {
    if (points.isEmpty) return input;
    if (input <= points.first.x) return points.first.y;
    if (input >= points.last.x) return points.last.y;
    
    for (int i = 0; i < points.length - 1; i++) {
      if (input >= points[i].x && input <= points[i + 1].x) {
        final t = (input - points[i].x) / (points[i + 1].x - points[i].x);
        return points[i].y + (points[i + 1].y - points[i].y) * t;
      }
    }
    return input;
  }

  Map<String, dynamic> toJson() => {
    'channel': channel,
    'points': points.map((p) => p.toJson()).toList(),
  };

  factory ColorCurve.fromJson(Map<String, dynamic> j) => ColorCurve(
    channel: j['channel'],
    points: (j['points'] as List).map((p) => ColorPoint.fromJson(p)).toList(),
  );

  @override
  List<Object?> get props => [channel, points];
}

class ColorWheel extends Equatable {
  final double hue;        // -180 to 180
  final double saturation; // -100 to 100
  final double luminance;  // -100 to 100

  const ColorWheel({
    this.hue = 0,
    this.saturation = 0,
    this.luminance = 0,
  });

  ColorWheel copyWith({double? hue, double? saturation, double? luminance}) => ColorWheel(
    hue: hue ?? this.hue,
    saturation: saturation ?? this.saturation,
    luminance: luminance ?? this.luminance,
  );

  Map<String, dynamic> toJson() => {
    'hue': hue,
    'saturation': saturation,
    'luminance': luminance,
  };

  factory ColorWheel.fromJson(Map<String, dynamic> j) => ColorWheel(
    hue: j['hue'] ?? 0,
    saturation: j['saturation'] ?? 0,
    luminance: j['luminance'] ?? 0,
  );

  @override
  List<Object?> get props => [hue, saturation, luminance];
}

class AdvancedColorGrade extends Equatable {
  final List<ColorCurve> curves;
  final ColorWheel shadows;
  final ColorWheel midtones;
  final ColorWheel highlights;
  final bool skinProtection;

  const AdvancedColorGrade({
    this.curves = const [],
    this.shadows = const ColorWheel(),
    this.midtones = const ColorWheel(),
    this.highlights = const ColorWheel(),
    this.skinProtection = false,
  });

  Map<String, dynamic> toJson() => {
    'curves': curves.map((c) => c.toJson()).toList(),
    'shadows': shadows.toJson(),
    'midtones': midtones.toJson(),
    'highlights': highlights.toJson(),
    'skinProtection': skinProtection,
  };

  factory AdvancedColorGrade.fromJson(Map<String, dynamic> j) => AdvancedColorGrade(
    curves: (j['curves'] as List? ?? []).map((c) => ColorCurve.fromJson(c)).toList(),
    shadows: ColorWheel.fromJson(j['shadows'] ?? {}),
    midtones: ColorWheel.fromJson(j['midtones'] ?? {}),
    highlights: ColorWheel.fromJson(j['highlights'] ?? {}),
    skinProtection: j['skinProtection'] ?? false,
  );

  @override
  List<Object?> get props => [curves, shadows, midtones, highlights, skinProtection];
}

// ============================================================================
// 5. MOTION TRACKING
// ============================================================================

class TrackedPoint extends Equatable {
  final double time;
  final Offset position;
  final double confidence;

  const TrackedPoint({
    required this.time,
    required this.position,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'position': {'dx': position.dx, 'dy': position.dy},
    'confidence': confidence,
  };

  factory TrackedPoint.fromJson(Map<String, dynamic> j) => TrackedPoint(
    time: j['time'],
    position: Offset(j['position']['dx'], j['position']['dy']),
    confidence: j['confidence'] ?? 1.0,
  );

  @override
  List<Object?> get props => [time, position, confidence];
}

class MotionTrack extends Equatable {
  final String id;
  final String targetId;  // clip id to track
  final List<TrackedPoint> points;
  final double smoothness;
  final bool attachToTarget;

  const MotionTrack({
    required this.id,
    required this.targetId,
    this.points = const [],
    this.smoothness = 0.5,
    this.attachToTarget = true,
  });

  factory MotionTrack.create({required String targetId}) => MotionTrack(
    id: _uuid.v4(),
    targetId: targetId,
  );

  Offset? getPositionAtTime(double time) {
    if (points.isEmpty) return null;
    if (points.length == 1) return points.first.position;
    
    TrackedPoint? prev;
    TrackedPoint? next;
    
    for (final p in points) {
      if (p.time <= time) prev = p;
      if (p.time >= time && next == null) next = p;
    }
    
    if (prev == null) return points.first.position;
    if (next == null) return prev.position;
    if (prev.time == next.time) return prev.position;
    
    final t = (time - prev.time) / (next.time - prev.time);
    final x = prev.position.dx + (next.position.dx - prev.position.dx) * t;
    final y = prev.position.dy + (next.position.dy - prev.position.dy) * t;
    
    return Offset(x, y);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'targetId': targetId,
    'points': points.map((p) => p.toJson()).toList(),
    'smoothness': smoothness,
    'attachToTarget': attachToTarget,
  };

  factory MotionTrack.fromJson(Map<String, dynamic> j) => MotionTrack(
    id: j['id'],
    targetId: j['targetId'],
    points: (j['points'] as List).map((p) => TrackedPoint.fromJson(p)).toList(),
    smoothness: j['smoothness'] ?? 0.5,
    attachToTarget: j['attachToTarget'] ?? true,
  );

  @override
  List<Object?> get props => [id, targetId, points];
}

// ============================================================================
// 6. PARTICLE EFFECTS (Fire, Snow, Rain)
// ============================================================================

enum ParticleType { fire, snow, rain, spark, smoke, bubble, confetti }

class ParticleEffect extends Equatable {
  final String id;
  final ParticleType type;
  final bool enabled;
  final int particleCount;
  final double speed;
  final double spread;
  final double size;
  final Color color;
  final double opacity;
  final double lifetime;
  final bool loop;

  const ParticleEffect({
    required this.id,
    required this.type,
    this.enabled = true,
    this.particleCount = 100,
    this.speed = 1.0,
    this.spread = 1.0,
    this.size = 1.0,
    this.color = Colors.white,
    this.opacity = 1.0,
    this.lifetime = 2.0,
    this.loop = true,
  });

  factory ParticleEffect.create({required ParticleType type}) => ParticleEffect(
    id: _uuid.v4(),
    type: type,
  );

  ParticleEffect copyWith({
    int? particleCount,
    double? speed,
    double? spread,
    double? size,
    Color? color,
    double? opacity,
  }) => ParticleEffect(
    id: id,
    type: type,
    enabled: enabled,
    particleCount: particleCount ?? this.particleCount,
    speed: speed ?? this.speed,
    spread: spread ?? this.spread,
    size: size ?? this.size,
    color: color ?? this.color,
    opacity: opacity ?? this.opacity,
    lifetime: lifetime,
    loop: loop,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'enabled': enabled,
    'particleCount': particleCount,
    'speed': speed,
    'spread': spread,
    'size': size,
    'color': color.toARGB32(),
    'opacity': opacity,
    'lifetime': lifetime,
    'loop': loop,
  };

  factory ParticleEffect.fromJson(Map<String, dynamic> j) => ParticleEffect(
    id: j['id'],
    type: ParticleType.values.byName(j['type']),
    enabled: j['enabled'] ?? true,
    particleCount: j['particleCount'] ?? 100,
    speed: j['speed'] ?? 1.0,
    spread: j['spread'] ?? 1.0,
    size: j['size'] ?? 1.0,
    color: Color(j['color'] ?? 0xFFFFFFFF),
    opacity: j['opacity'] ?? 1.0,
    lifetime: j['lifetime'] ?? 2.0,
    loop: j['loop'] ?? true,
  );

  @override
  List<Object?> get props => [id, type, particleCount, speed, spread];
}

// ============================================================================
// 7. BEAT DETECTION
// ============================================================================

class Beat extends Equatable {
  final double time;
  final double intensity;
  final int bpm;

  const Beat({
    required this.time,
    required this.intensity,
    required this.bpm,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'intensity': intensity,
    'bpm': bpm,
  };

  factory Beat.fromJson(Map<String, dynamic> j) => Beat(
    time: j['time'],
    intensity: j['intensity'],
    bpm: j['bpm'],
  );

  @override
  List<Object?> get props => [time, intensity, bpm];
}

class BeatTrack extends Equatable {
  final List<Beat> beats;
  final double averageBpm;
  final double confidence;

  const BeatTrack({
    this.beats = const [],
    this.averageBpm = 0,
    this.confidence = 0,
  });

  List<Beat> getBeatsInRange(double start, double end) {
    return beats.where((b) => b.time >= start && b.time <= end).toList();
  }

  Beat? getNearestBeat(double time) {
    if (beats.isEmpty) return null;
    return beats.reduce((a, b) => (a.time - time).abs() < (b.time - time).abs() ? a : b);
  }

  Map<String, dynamic> toJson() => {
    'beats': beats.map((b) => b.toJson()).toList(),
    'averageBpm': averageBpm,
    'confidence': confidence,
  };

  factory BeatTrack.fromJson(Map<String, dynamic> j) => BeatTrack(
    beats: (j['beats'] as List).map((b) => Beat.fromJson(b)).toList(),
    averageBpm: j['averageBpm'] ?? 0,
    confidence: j['confidence'] ?? 0,
  );

  @override
  List<Object?> get props => [beats, averageBpm, confidence];
}

// ============================================================================
// 8. EXPORT QUEUE
// ============================================================================

enum ExportJobStatus { pending, processing, completed, failed, cancelled }

class ExportJob extends Equatable {
  final String id;
  final String projectId;
  final String outputPath;
  final ExportQuality quality;
  final bool useH265;
  final DateTime createdAt;
  final ExportJobStatus status;
  final double progress;
  final String? error;
  final DateTime? completedAt;

  const ExportJob({
    required this.id,
    required this.projectId,
    required this.outputPath,
    required this.quality,
    required this.useH265,
    required this.createdAt,
    this.status = ExportJobStatus.pending,
    this.progress = 0,
    this.error,
    this.completedAt,
  });

  factory ExportJob.create({
    required String projectId,
    required String outputPath,
    ExportQuality quality = ExportQuality.q1080p,
    bool useH265 = false,
  }) => ExportJob(
    id: _uuid.v4(),
    projectId: projectId,
    outputPath: outputPath,
    quality: quality,
    useH265: useH265,
    createdAt: DateTime.now(),
  );

  ExportJob copyWith({
    ExportJobStatus? status,
    double? progress,
    String? error,
    DateTime? completedAt,
  }) => ExportJob(
    id: id,
    projectId: projectId,
    outputPath: outputPath,
    quality: quality,
    useH265: useH265,
    createdAt: createdAt,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: error ?? this.error,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'outputPath': outputPath,
    'quality': quality.name,
    'useH265': useH265,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'progress': progress,
    'error': error,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory ExportJob.fromJson(Map<String, dynamic> j) => ExportJob(
    id: j['id'],
    projectId: j['projectId'],
    outputPath: j['outputPath'],
    quality: ExportQuality.values.byName(j['quality']),
    useH265: j['useH265'] ?? false,
    createdAt: DateTime.parse(j['createdAt']),
    status: ExportJobStatus.values.byName(j['status'] ?? 'pending'),
    progress: j['progress'] ?? 0,
    error: j['error'],
    completedAt: j['completedAt'] != null ? DateTime.parse(j['completedAt']) : null,
  );

  @override
  List<Object?> get props => [id, projectId, status, progress];
}

// ============================================================================
// 9. Easing Type (re-exported for convenience)
// ============================================================================

enum EasingType {
  linear,
  ease,
  easeIn,
  easeOut,
  bezier,
}
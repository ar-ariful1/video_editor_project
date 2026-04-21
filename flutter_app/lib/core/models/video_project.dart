// lib/core/models/video_project.dart
// Core data models for the video editor timeline

import 'auto_caption.dart';
import 'package:uuid/uuid.dart';
import 'advanced_features.dart';
import 'package:equatable/equatable.dart';

export 'advanced_features.dart';
export 'auto_caption.dart';


const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum TrackType { video, audio, text, sticker, effect, adjustment }
enum BlendMode { normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, hardLight, softLight, difference, exclusion }
enum EasingType { linear, ease, easeIn, easeOut, bezier }
enum ProjectStatus { draft, exported, deleted }
enum ExportQuality { q720p, q1080p, q4k }
enum FillType { solid, linearGradient, radialGradient }
enum TextAlignment { left, center, right, justify }

// ─────────────────────────────────────────────────────────────────────────────
// KEYFRAME
// ─────────────────────────────────────────────────────────────────────────────

class Keyframe extends Equatable {
  final String id;
  final double time;           // position in seconds
  final String property;       // 'x' | 'y' | 'scaleX' | 'scaleY' | 'rotation' | 'opacity' | etc.
  final dynamic value;
  final EasingType easing;
  final List<double> bezierHandles; // [p1x, p1y, p2x, p2y]

  double get p1x => bezierHandles[0];
  double get p1y => bezierHandles[1];
  double get p2x => bezierHandles[2];
  double get p2y => bezierHandles[3];

  const Keyframe({
    required this.id,
    required this.time,
    required this.property,
    required this.value,
    this.easing = EasingType.ease,
    this.bezierHandles = const [0.25, 0.1, 0.25, 1.0],
  });

  factory Keyframe.create({
    required double time,
    required String property,
    required dynamic value,
    EasingType easing = EasingType.ease,
  }) => Keyframe(id: _uuid.v4(), time: time, property: property, value: value, easing: easing);

  Keyframe copyWith({String? id, double? time, String? property, dynamic value, EasingType? easing, List<double>? bezierHandles}) {
    return Keyframe(
      id: id ?? this.id,
      time: time ?? this.time,
      property: property ?? this.property,
      value: value ?? this.value,
      easing: easing ?? this.easing,
      bezierHandles: bezierHandles ?? this.bezierHandles,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'time': time, 'property': property,
    'value': value, 'easing': easing.name,
    'bezierHandles': bezierHandles,
  };

  factory Keyframe.fromJson(Map<String, dynamic> j) => Keyframe(
    id: j['id'], time: j['time'], property: j['property'],
    value: j['value'], easing: EasingType.values.byName(j['easing']),
    bezierHandles: List<double>.from(j['bezierHandles']),
  );

  @override
  List<Object?> get props => [id, time, property, value, easing];
}

// ─────────────────────────────────────────────────────────────────────────────
// KEYFRAME ANIMATION 
// ─────────────────────────────────────────────────────────────────────────────

class KeyframeAnimation extends Equatable {
  final String id;
  final List<Keyframe> keyframes;
  final String name;
  final bool isLooping;
  final double duration;
  
  const KeyframeAnimation({
    required this.id,
    required this.keyframes,
    this.name = 'Animation',
    this.isLooping = false,
    this.duration = 0,
  });

  factory KeyframeAnimation.create({String name = 'Animation'}) => KeyframeAnimation(
    id: _uuid.v4(),
    keyframes: [],
    name: name,
  );

  bool get hasKeyframes => keyframes.isNotEmpty;
  
  double get maxTime {
    if (keyframes.isEmpty) return 0;
    return keyframes.map((k) => k.time).reduce((a, b) => a > b ? a : b);
  }

  List<Keyframe> getKeyframesByProperty(String property) {
    return keyframes.where((k) => k.property == property).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  dynamic getValueAtTime(double time, String property) {
    final frames = getKeyframesByProperty(property);
    if (frames.isEmpty) return null;
    if (frames.length == 1) return frames.first.value;
    
    // Handle looping
    double normalizedTime = time;
    if (isLooping && maxTime > 0 && time > maxTime) {
      normalizedTime = time % maxTime;
    }
    
    // Find surrounding keyframes
    Keyframe? prev;
    Keyframe? next;
    
    for (final frame in frames) {
      if (frame.time <= normalizedTime) {
        prev = frame;
      }
      if (frame.time >= normalizedTime && next == null) {
        next = frame;
      }
    }
    
    if (prev == null) return frames.first.value;
    if (next == null) return prev.value;
    if (prev.time == next.time) return prev.value;
    
    // Interpolate
    final t = (normalizedTime - prev.time) / (next.time - prev.time);
    final curvedT = _interpolateCurve(t, prev.easing, prev.bezierHandles);
    
    final prevValue = prev.value is num ? (prev.value as num).toDouble() : 0;
    final nextValue = next.value is num ? (next.value as num).toDouble() : 0;
    
    return prevValue + (nextValue - prevValue) * curvedT;
  }

  double _interpolateCurve(double t, EasingType easing, List<double> handles) {
    switch (easing) {
      case EasingType.linear: return t;
      case EasingType.ease: return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
      case EasingType.easeIn: return t * t;
      case EasingType.easeOut: return t * (2 - t);
      case EasingType.bezier: return _cubicBezier(handles[0], handles[1], handles[2], handles[3], t);
    }
  }

  double _cubicBezier(double p1x, double p1y, double p2x, double p2y, double t) {
    double cx = 3 * p1x, bx = 3 * (p2x - p1x) - cx, ax = 1 - cx - bx;
    double cy = 3 * p1y, by = 3 * (p2y - p1y) - cy, ay = 1 - cy - by;
    double st = t;
    for (int i = 0; i < 8; i++) {
      double fx = ((ax * st + bx) * st + cx) * st - t;
      double dfx = (3 * ax * st + 2 * bx) * st + cx;
      if (dfx.abs() < 1e-6) break;
      st -= fx / dfx;
    }
    return ((ay * st + by) * st + cy) * st;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITY METHODS
  // ─────────────────────────────────────────────────────────────────────────

  KeyframeAnimation copyWith({
    String? id,
    List<Keyframe>? keyframes,
    String? name,
    bool? isLooping,
    double? duration,
  }) {
    return KeyframeAnimation(
      id: id ?? this.id,
      keyframes: keyframes ?? this.keyframes,
      name: name ?? this.name,
      isLooping: isLooping ?? this.isLooping,
      duration: duration ?? this.duration,
    );
  }

  KeyframeAnimation addKeyframe(Keyframe keyframe) {
    final newKeyframes = [...keyframes, keyframe];
    return KeyframeAnimation(
      id: id,
      keyframes: newKeyframes,
      name: name,
      isLooping: isLooping,
      duration: duration,
    );
  }

  KeyframeAnimation removeKeyframe(String keyframeId) {
    final newKeyframes = keyframes.where((k) => k.id != keyframeId).toList();
    return KeyframeAnimation(
      id: id,
      keyframes: newKeyframes,
      name: name,
      isLooping: isLooping,
      duration: duration,
    );
  }

  KeyframeAnimation updateKeyframe(Keyframe keyframe) {
    final index = keyframes.indexWhere((k) => k.id == keyframe.id);
    if (index == -1) return this;
    
    final newKeyframes = List<Keyframe>.from(keyframes);
    newKeyframes[index] = keyframe;
    
    return KeyframeAnimation(
      id: id,
      keyframes: newKeyframes,
      name: name,
      isLooping: isLooping,
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'keyframes': keyframes.map((k) => k.toJson()).toList(),
    'name': name,
    'isLooping': isLooping,
    'duration': duration,
  };

  factory KeyframeAnimation.fromJson(Map<String, dynamic> j) => KeyframeAnimation(
    id: j['id'],
    keyframes: (j['keyframes'] as List).map((k) => Keyframe.fromJson(k)).toList(),
    name: j['name'] ?? 'Animation',
    isLooping: j['isLooping'] ?? false,
    duration: j['duration'] ?? 0,
  );

  @override
  List<Object?> get props => [id, keyframes, name, isLooping, duration];
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSFORM 3D
// ─────────────────────────────────────────────────────────────────────────────

class Transform3D extends Equatable {
  final double x;
  final double y;
  final double scaleX;
  final double scaleY;
  final double rotation;   // degrees
  final double skewX;
  final double skewY;

  const Transform3D({
    this.x = 0, this.y = 0,
    this.scaleX = 1.0, this.scaleY = 1.0,
    this.rotation = 0, this.skewX = 0, this.skewY = 0,
  });

  static const identity = Transform3D();

  Transform3D copyWith({double? x, double? y, double? scaleX, double? scaleY, double? rotation, double? skewX, double? skewY}) {
    return Transform3D(
      x: x ?? this.x, y: y ?? this.y,
      scaleX: scaleX ?? this.scaleX, scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation, skewX: skewX ?? this.skewX, skewY: skewY ?? this.skewY,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'scaleX': scaleX, 'scaleY': scaleY, 'rotation': rotation, 'skewX': skewX, 'skewY': skewY};
  factory Transform3D.fromJson(Map<String, dynamic> j) => Transform3D(x: j['x'], y: j['y'], scaleX: j['scaleX'], scaleY: j['scaleY'], rotation: j['rotation'], skewX: j['skewX'], skewY: j['skewY']);

  @override
  List<Object?> get props => [x, y, scaleX, scaleY, rotation, skewX, skewY];
}

// ─────────────────────────────────────────────────────────────────────────────
// COLOR GRADE
// ─────────────────────────────────────────────────────────────────────────────

class ColorGrade extends Equatable {
  final double exposure;
  final double brightness;
  final double contrast;
  final double highlights;
  final double shadows;
  final double whites;
  final double blacks;
  final double temperature;   // -100 to +100
  final double tint;
  final double saturation;
  final double vibrance;
  final String? lutPath;      // .cube LUT file path
  final double lutIntensity;

  const ColorGrade({
    this.exposure = 0, this.brightness = 0, this.contrast = 0,
    this.highlights = 0, this.shadows = 0, this.whites = 0, this.blacks = 0,
    this.temperature = 0, this.tint = 0, this.saturation = 0, this.vibrance = 0,
    this.lutPath, this.lutIntensity = 1.0,
  });

  static const identity = ColorGrade();

  bool get isIdentity => exposure == 0 && brightness == 0 && contrast == 0 &&
      highlights == 0 && shadows == 0 && saturation == 0 && lutPath == null;

  ColorGrade copyWith({
    double? exposure, double? brightness, double? contrast,
    double? highlights, double? shadows, double? whites, double? blacks,
    double? temperature, double? tint, double? saturation, double? vibrance,
    String? lutPath, double? lutIntensity,
  }) => ColorGrade(
    exposure: exposure ?? this.exposure, brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast, highlights: highlights ?? this.highlights,
    shadows: shadows ?? this.shadows, whites: whites ?? this.whites,
    blacks: blacks ?? this.blacks, temperature: temperature ?? this.temperature,
    tint: tint ?? this.tint, saturation: saturation ?? this.saturation,
    vibrance: vibrance ?? this.vibrance, lutPath: lutPath ?? this.lutPath,
    lutIntensity: lutIntensity ?? this.lutIntensity,
  );

  Map<String, dynamic> toJson() => {
    'exposure': exposure, 'brightness': brightness, 'contrast': contrast,
    'highlights': highlights, 'shadows': shadows, 'whites': whites, 'blacks': blacks,
    'temperature': temperature, 'tint': tint, 'saturation': saturation, 'vibrance': vibrance,
    'lutPath': lutPath, 'lutIntensity': lutIntensity,
  };

  factory ColorGrade.fromJson(Map<String, dynamic> j) => ColorGrade(
    exposure: j['exposure'] ?? 0, brightness: j['brightness'] ?? 0,
    contrast: j['contrast'] ?? 0, highlights: j['highlights'] ?? 0,
    shadows: j['shadows'] ?? 0, whites: j['whites'] ?? 0, blacks: j['blacks'] ?? 0,
    temperature: j['temperature'] ?? 0, tint: j['tint'] ?? 0,
    saturation: j['saturation'] ?? 0, vibrance: j['vibrance'] ?? 0,
    lutPath: j['lutPath'], lutIntensity: j['lutIntensity'] ?? 1.0,
  );

  @override
  List<Object?> get props => [exposure, brightness, contrast, highlights, shadows, whites, blacks, temperature, tint, saturation, vibrance, lutPath, lutIntensity];
}

// ─────────────────────────────────────────────────────────────────────────────
// EFFECT
// ─────────────────────────────────────────────────────────────────────────────

class Effect extends Equatable {
  final String id;
  final String type;          // 'glitch' | 'vhs' | 'blur' | 'grain' | 'vignette' | etc.
  final Map<String, dynamic> params;
  final double intensity;     // 0.0 to 1.0
  final bool enabled;

  const Effect({
    required this.id,
    required this.type,
    this.params = const {},
    this.intensity = 1.0,
    this.enabled = true,
  });

  factory Effect.create({required String type, Map<String, dynamic> params = const {}, double intensity = 1.0}) =>
      Effect(id: _uuid.v4(), type: type, params: params, intensity: intensity);

  Effect copyWith({String? id, String? type, Map<String, dynamic>? params, double? intensity, bool? enabled}) =>
      Effect(id: id ?? this.id, type: type ?? this.type, params: params ?? this.params, intensity: intensity ?? this.intensity, enabled: enabled ?? this.enabled);

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'params': params, 'intensity': intensity, 'enabled': enabled};
  factory Effect.fromJson(Map<String, dynamic> j) => Effect(id: j['id'], type: j['type'], params: Map<String, dynamic>.from(j['params'] ?? {}), intensity: j['intensity'] ?? 1.0, enabled: j['enabled'] ?? true);

  @override
  List<Object?> get props => [id, type, params, intensity, enabled];
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSITION
// ─────────────────────────────────────────────────────────────────────────────

class Transition extends Equatable {
  final String type;    // 'fade' | 'slide' | 'zoom' | 'spin' | 'cube' | 'wipe' | etc.
  final double duration;
  final String? direction;
  final Map<String, dynamic> params;

  const Transition({required this.type, this.duration = 0.5, this.direction, this.params = const {}});

  Map<String, dynamic> toJson() => {'type': type, 'duration': duration, 'direction': direction, 'params': params};
  factory Transition.fromJson(Map<String, dynamic> j) => Transition(type: j['type'], duration: j['duration'] ?? 0.5, direction: j['direction'], params: Map<String, dynamic>.from(j['params'] ?? {}));

  @override
  List<Object?> get props => [type, duration, direction];
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT FILL & STROKE
// ─────────────────────────────────────────────────────────────────────────────

class TextFill extends Equatable {
  final FillType type;
  final List<int> colors;   // ARGB ints
  final List<double> stops;
  final double angle;

  const TextFill({this.type = FillType.solid, this.colors = const [0xFFFFFFFF], this.stops = const [0.0], this.angle = 0});

  Map<String, dynamic> toJson() => {'type': type.name, 'colors': colors, 'stops': stops, 'angle': angle};
  factory TextFill.fromJson(Map<String, dynamic> j) => TextFill(type: FillType.values.byName(j['type']), colors: List<int>.from(j['colors']), stops: List<double>.from(j['stops']), angle: j['angle'] ?? 0);

  @override
  List<Object?> get props => [type, colors, stops, angle];
}

class TextStroke extends Equatable {
  final double width;
  final int color;  // ARGB

  const TextStroke({this.width = 0, this.color = 0xFF000000});
  Map<String, dynamic> toJson() => {'width': width, 'color': color};
  factory TextStroke.fromJson(Map<String, dynamic> j) => TextStroke(width: j['width'], color: j['color']);

  @override
  List<Object?> get props => [width, color];
}

class TextShadow extends Equatable {
  final double offsetX;
  final double offsetY;
  final double blur;
  final int color;
  final bool enabled;

  const TextShadow({this.offsetX = 2, this.offsetY = 2, this.blur = 4, this.color = 0x88000000, this.enabled = false});
  Map<String, dynamic> toJson() => {'offsetX': offsetX, 'offsetY': offsetY, 'blur': blur, 'color': color, 'enabled': enabled};
  factory TextShadow.fromJson(Map<String, dynamic> j) => TextShadow(offsetX: j['offsetX'], offsetY: j['offsetY'], blur: j['blur'], color: j['color'], enabled: j['enabled']);

  @override
  List<Object?> get props => [offsetX, offsetY, blur, color, enabled];
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIP
// ─────────────────────────────────────────────────────────────────────────────

class Clip extends Equatable {
  final String id;
  final double startTime;     // position on timeline (seconds)
  final double endTime;
  final double trimStart;     // source media trim in point
  final double trimEnd;       // source media trim out point
  final double fadeIn;        // fade in duration in seconds
  final double fadeOut;       // fade out duration in seconds
  final String? mediaPath;    // local file path or CDN URL
  final String? mediaType;    // 'video' | 'image' | 'audio'
  final double speed;         // 0.1x – 100x
  final bool isReversed;
  final List<Effect> effects;
  final List<Keyframe> keyframes;
  final KeyframeAnimation? animation;  // CapCut style animation
  final BlendMode blendMode;
  final double opacity;
  final Transform3D transform;
  final ColorGrade? colorGrade;
  final Transition? transitionIn;
  final Transition? transitionOut;
  final bool isMuted;
  final double volume;
  final String? textContent;
  final Map<String, dynamic>? textStyle;
  final bool isAdjustmentLayer;
  final bool isTextLayer;  // Flag to identify text layer
  final ChromaKey? chromaKey;           // Green screen
  final Mask? mask;                      // Masking
  final AudioEnvelope? audioEnvelope;    // Audio keyframes
  final bool noiseReduction;             // RNNoise / afftdn
  final AdvancedColorGrade? advancedColorGrade; // Color curves & wheels
  final MotionTrack? motionTrack;        // Motion tracking
  final ParticleEffect? particleEffect;  // Fire, snow, rain
  final List<AutoCaption>? autoCaptions; 

  const Clip({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.trimStart = 0,
    this.trimEnd = 0,
    this.fadeIn = 0,
    this.fadeOut = 0,
    this.mediaPath,
    this.mediaType,
    this.speed = 1.0,
    this.isReversed = false,
    this.isAdjustmentLayer = false,
    this.isTextLayer = false,
    this.effects = const [],
    this.keyframes = const [],
    this.animation,
    this.blendMode = BlendMode.normal,
    this.opacity = 1.0,
    this.transform = Transform3D.identity,
    this.colorGrade,
    this.transitionIn,
    this.transitionOut,
    this.isMuted = false,
    this.volume = 1.0,
    this.textContent,
    this.textStyle,
    this.chromaKey,
    this.mask,
    this.audioEnvelope,
    this.noiseReduction = false,
    this.advancedColorGrade,
    this.motionTrack,
    this.particleEffect,
    this.autoCaptions,
  });

  factory Clip.create({
    required double startTime,
    required double endTime,
    String? mediaPath,
    String? mediaType,
  }) => Clip(id: _uuid.v4(), startTime: startTime, endTime: endTime, mediaPath: mediaPath, mediaType: mediaType);

  double get duration => endTime - startTime;

  // Get keyframe value at given time with interpolation
  double? getKeyframeValue(String property, double time) {
    final propKeyframes = keyframes.where((k) => k.property == property).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (propKeyframes.isEmpty) return null;
    if (propKeyframes.length == 1) return (propKeyframes.first.value as num).toDouble();

    final prev = propKeyframes.lastWhere((k) => k.time <= time, orElse: () => propKeyframes.first);
    final next = propKeyframes.firstWhere((k) => k.time > time, orElse: () => propKeyframes.last);
    if (prev == next) return (prev.value as num).toDouble();

    final t = (time - prev.time) / (next.time - prev.time);
    final a = (prev.value as num).toDouble();
    final b = (next.value as num).toDouble();
    return _interpolate(a, b, t.clamp(0.0, 1.0), prev.easing, prev.bezierHandles);
  }

  static double _interpolate(double a, double b, double t, EasingType easing, List<double> handles) {
    switch (easing) {
      case EasingType.linear: return a + (b - a) * t;
      case EasingType.ease:   return a + (b - a) * _easeInOut(t);
      case EasingType.easeIn: return a + (b - a) * (t * t);
      case EasingType.easeOut:return a + (b - a) * (t * (2 - t));
      case EasingType.bezier: return a + (b - a) * _cubicBezier(handles[0], handles[1], handles[2], handles[3], t);
    }
  }

  static double _easeInOut(double t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
  
  static double _cubicBezier(double p1x, double p1y, double p2x, double p2y, double t) {
    double cx = 3 * p1x, bx = 3 * (p2x - p1x) - cx, ax = 1 - cx - bx;
    double cy = 3 * p1y, by = 3 * (p2y - p1y) - cy, ay = 1 - cy - by;
    double st = t;
    for (int i = 0; i < 8; i++) {
      double fx = ((ax * st + bx) * st + cx) * st - t;
      double dfx = (3 * ax * st + 2 * bx) * st + cx;
      if (dfx.abs() < 1e-6) break;
      st -= fx / dfx;
    }
    return ((ay * st + by) * st + cy) * st;
  }

  Clip copyWith({
    String? id,
    double? startTime, double? endTime, double? trimStart, double? trimEnd,
    double? fadeIn, double? fadeOut,
    String? mediaPath, String? mediaType, double? speed, bool? isReversed,
    bool? isAdjustmentLayer, bool? isTextLayer,
    List<Effect>? effects, List<Keyframe>? keyframes, KeyframeAnimation? animation,
    BlendMode? blendMode, double? opacity, Transform3D? transform, ColorGrade? colorGrade,
    Transition? transitionIn, Transition? transitionOut, bool? isMuted, double? volume,
    String? textContent, Map<String, dynamic>? textStyle,
    ChromaKey? chromaKey,
    Mask? mask,
    AudioEnvelope? audioEnvelope,
    bool? noiseReduction,
    AdvancedColorGrade? advancedColorGrade,
    MotionTrack? motionTrack,
    ParticleEffect? particleEffect,
    List<AutoCaption>? autoCaptions,
  }) => Clip(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime, endTime: endTime ?? this.endTime,
    trimStart: trimStart ?? this.trimStart, trimEnd: trimEnd ?? this.trimEnd,
    fadeIn: fadeIn ?? this.fadeIn, fadeOut: fadeOut ?? this.fadeOut,
    mediaPath: mediaPath ?? this.mediaPath, mediaType: mediaType ?? this.mediaType,
    speed: speed ?? this.speed, isReversed: isReversed ?? this.isReversed,
    isAdjustmentLayer: isAdjustmentLayer ?? this.isAdjustmentLayer,
    isTextLayer: isTextLayer ?? this.isTextLayer,
    effects: effects ?? this.effects, keyframes: keyframes ?? this.keyframes,
    animation: animation ?? this.animation,
    blendMode: blendMode ?? this.blendMode, opacity: opacity ?? this.opacity,
    transform: transform ?? this.transform, colorGrade: colorGrade ?? this.colorGrade,
    transitionIn: transitionIn ?? this.transitionIn, transitionOut: transitionOut ?? this.transitionOut,
    isMuted: isMuted ?? this.isMuted, volume: volume ?? this.volume,
    textContent: textContent ?? this.textContent, textStyle: textStyle ?? this.textStyle,
    chromaKey: chromaKey ?? this.chromaKey,
    mask: mask ?? this.mask,
    audioEnvelope: audioEnvelope ?? this.audioEnvelope,
    noiseReduction: noiseReduction ?? this.noiseReduction,
    advancedColorGrade: advancedColorGrade ?? this.advancedColorGrade,
    motionTrack: motionTrack ?? this.motionTrack,
    particleEffect: particleEffect ?? this.particleEffect,
    autoCaptions: autoCaptions ?? this.autoCaptions,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'startTime': startTime, 'endTime': endTime,
    'trimStart': trimStart, 'trimEnd': trimEnd,
    'fadeIn': fadeIn, 'fadeOut': fadeOut,
    'mediaPath': mediaPath, 'mediaType': mediaType, 'speed': speed, 'isReversed': isReversed,
    'isAdjustmentLayer': isAdjustmentLayer, 'isTextLayer': isTextLayer,
    'effects': effects.map((e) => e.toJson()).toList(),
    'keyframes': keyframes.map((k) => k.toJson()).toList(),
    'animation': animation?.toJson(),
    'blendMode': blendMode.name, 'opacity': opacity,
    'transform': transform.toJson(), 'colorGrade': colorGrade?.toJson(),
    'transitionIn': transitionIn?.toJson(), 'transitionOut': transitionOut?.toJson(),
    'isMuted': isMuted, 'volume': volume,
    'textContent': textContent, 'textStyle': textStyle,
    'chromaKey': chromaKey?.toJson(),
    'mask': mask?.toJson(),
    'audioEnvelope': audioEnvelope?.toJson(),
    'noiseReduction': noiseReduction,
    'advancedColorGrade': advancedColorGrade?.toJson(),
    'motionTrack': motionTrack?.toJson(),
    'particleEffect': particleEffect?.toJson(),
    'autoCaptions': autoCaptions?.map((c) => c.toJson()).toList(),
  };

  factory Clip.fromJson(Map<String, dynamic> j) => Clip(
    id: j['id'], startTime: j['startTime'], endTime: j['endTime'],
    trimStart: j['trimStart'] ?? j['trimIn'] ?? 0,
    trimEnd: j['trimEnd'] ?? j['trimOut'] ?? 0,
    fadeIn: j['fadeIn'] ?? 0, fadeOut: j['fadeOut'] ?? 0,
    mediaPath: j['mediaPath'], mediaType: j['mediaType'],
    speed: j['speed'] ?? 1.0, isReversed: j['isReversed'] ?? false,
    isAdjustmentLayer: j['isAdjustmentLayer'] ?? false,
    isTextLayer: j['isTextLayer'] ?? false,
    effects: (j['effects'] as List? ?? []).map((e) => Effect.fromJson(e)).toList(),
    keyframes: (j['keyframes'] as List? ?? []).map((k) => Keyframe.fromJson(k)).toList(),
    animation: j['animation'] != null ? KeyframeAnimation.fromJson(j['animation']) : null,
    blendMode: BlendMode.values.byName(j['blendMode'] ?? 'normal'),
    opacity: j['opacity'] ?? 1.0,
    transform: j['transform'] != null ? Transform3D.fromJson(j['transform']) : Transform3D.identity,
    colorGrade: j['colorGrade'] != null ? ColorGrade.fromJson(j['colorGrade']) : null,
    transitionIn: j['transitionIn'] != null ? Transition.fromJson(j['transitionIn']) : null,
    transitionOut: j['transitionOut'] != null ? Transition.fromJson(j['transitionOut']) : null,
    isMuted: j['isMuted'] ?? false, volume: j['volume'] ?? 1.0,
    textContent: j['textContent'],
    textStyle: j['textStyle'] != null ? Map<String, dynamic>.from(j['textStyle']) : null,
    chromaKey: j['chromaKey'] != null ? ChromaKey.fromJson(j['chromaKey']) : null,
    mask: j['mask'] != null ? Mask.fromJson(j['mask']) : null,
    audioEnvelope: j['audioEnvelope'] != null ? AudioEnvelope.fromJson(j['audioEnvelope']) : null,
    noiseReduction: j['noiseReduction'] ?? false,
    advancedColorGrade: j['advancedColorGrade'] != null ? AdvancedColorGrade.fromJson(j['advancedColorGrade']) : null,
    motionTrack: j['motionTrack'] != null ? MotionTrack.fromJson(j['motionTrack']) : null,
    particleEffect: j['particleEffect'] != null ? ParticleEffect.fromJson(j['particleEffect']) : null,
    autoCaptions: j['autoCaptions'] != null 
        ? (j['autoCaptions'] as List).map((c) => AutoCaption.fromJson(c)).toList()
        : null,
  );

  static Clip fromJsonPolymorphic(Map<String, dynamic> j) {
    if (j['isTextLayer'] == true) return TextLayer.fromJson(j);
    if (j['isAdjustmentLayer'] == true) return AdjustmentLayer.fromJson(j);
    return Clip.fromJson(j);
  }

  

  @override
  List<Object?> get props => [id, startTime, endTime, mediaPath, speed, blendMode, opacity];
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT LAYER (extends Clip)
// ─────────────────────────────────────────────────────────────────────────────

class TextLayer extends Clip {
  final String text;
  final String fontFamily;
  final double fontSize;
  final TextAlignment alignment;
  final TextFill fill;
  final TextStroke stroke;
  final TextShadow shadow;
  final String? animIn;   // 'fadeIn' | 'typewriter' | 'slideLeft' | etc.
  final String? animOut;
  final String? animLoop;
  final bool isAutoCaption;
  final double backgroundOpacity;
  final int backgroundColor;

  const TextLayer({
    required super.id,
    required super.startTime,
    required super.endTime,
    super.transform,
    super.opacity,
    super.animation,
    this.text = '',
    this.fontFamily = 'Inter',
    this.fontSize = 40,
    this.alignment = TextAlignment.center,
    this.fill = const TextFill(),
    this.stroke = const TextStroke(),
    this.shadow = const TextShadow(),
    this.animIn,
    this.animOut,
    this.animLoop,
    this.isAutoCaption = false,
    this.backgroundOpacity = 0,
    this.backgroundColor = 0x00000000,
  }) : super(
    isTextLayer: true,
    mediaType: 'text',
  );

  factory TextLayer.create({
    required double startTime,
    required double endTime,
    String text = 'Text',
    String? animIn,
    KeyframeAnimation? animation,
  }) => TextLayer(
    id: _uuid.v4(),
    startTime: startTime,
    endTime: endTime,
    text: text,
    animIn: animIn,
    animation: animation,
  );

  @override
  TextLayer copyWith({
    String? id,
    double? startTime,
    double? endTime,
    double? trimStart,
    double? trimEnd,
    double? fadeIn,
    double? fadeOut,
    String? mediaPath,
    String? mediaType,
    double? speed,
    bool? isReversed,
    bool? isAdjustmentLayer,
    bool? isTextLayer,
    List<Effect>? effects,
    List<Keyframe>? keyframes,
    KeyframeAnimation? animation,
    BlendMode? blendMode,
    double? opacity,
    Transform3D? transform,
    ColorGrade? colorGrade,
    Transition? transitionIn,
    Transition? transitionOut,
    bool? isMuted,
    double? volume,
    String? textContent,
    Map<String, dynamic>? textStyle,
    ChromaKey? chromaKey,
    Mask? mask,
    AudioEnvelope? audioEnvelope,
    bool? noiseReduction,
    AdvancedColorGrade? advancedColorGrade,
    MotionTrack? motionTrack,
    ParticleEffect? particleEffect,
    List<AutoCaption>? autoCaptions,
    // Text specific additions
    String? text,
    String? fontFamily,
    double? fontSize,
    TextAlignment? alignment,
    TextFill? fill,
    TextStroke? stroke,
    TextShadow? shadow,
    String? animIn,
    String? animOut,
    String? animLoop,
    bool? isAutoCaption,
    double? backgroundOpacity,
    int? backgroundColor,
  }) =>
      TextLayer(
        id: id ?? this.id,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        transform: transform ?? this.transform,
        opacity: opacity ?? this.opacity,
        animation: animation ?? this.animation,
        text: text ?? this.text,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        alignment: alignment ?? this.alignment,
        fill: fill ?? this.fill,
        stroke: stroke ?? this.stroke,
        shadow: shadow ?? this.shadow,
        animIn: animIn ?? this.animIn,
        animOut: animOut ?? this.animOut,
        animLoop: animLoop ?? this.animLoop,
        isAutoCaption: isAutoCaption ?? this.isAutoCaption,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
        backgroundColor: backgroundColor ?? this.backgroundColor,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'isTextLayer': true,
    'text': text, 'fontFamily': fontFamily, 'fontSize': fontSize,
    'alignment': alignment.name, 'fill': fill.toJson(), 'stroke': stroke.toJson(),
    'shadow': shadow.toJson(), 'animIn': animIn, 'animOut': animOut, 'animLoop': animLoop,
    'isAutoCaption': isAutoCaption, 'backgroundOpacity': backgroundOpacity, 'backgroundColor': backgroundColor,
  };

  factory TextLayer.fromJson(Map<String, dynamic> j) {
    final base = Clip.fromJson(j);
    return TextLayer(
      id: base.id,
      startTime: base.startTime,
      endTime: base.endTime,
      transform: base.transform,
      opacity: base.opacity,
      animation: base.animation,
      text: j['text'] ?? '',
      fontFamily: j['fontFamily'] ?? 'Inter',
      fontSize: j['fontSize'] ?? 40,
      alignment: TextAlignment.values.byName(j['alignment'] ?? 'center'),
      fill: j['fill'] != null ? TextFill.fromJson(j['fill']) : const TextFill(),
      stroke: j['stroke'] != null ? TextStroke.fromJson(j['stroke']) : const TextStroke(),
      shadow: j['shadow'] != null ? TextShadow.fromJson(j['shadow']) : const TextShadow(),
      animIn: j['animIn'],
      animOut: j['animOut'],
      animLoop: j['animLoop'],
      isAutoCaption: j['isAutoCaption'] ?? false,
      backgroundOpacity: j['backgroundOpacity'] ?? 0,
      backgroundColor: j['backgroundColor'] ?? 0x00000000,
    );
  }

  @override
  List<Object?> get props => [...super.props, text, fontFamily, fontSize, alignment];
}

// ─────────────────────────────────────────────────────────────────────────────
// ADJUSTMENT LAYER (extends Clip)
// ─────────────────────────────────────────────────────────────────────────────

class AdjustmentLayer extends Clip {
  final ColorGrade adjustmentColorGrade;
  final List<Effect> adjustmentEffects;

  const AdjustmentLayer({
    required super.id,
    required super.startTime,
    required super.endTime,
    this.adjustmentColorGrade = const ColorGrade(),
    this.adjustmentEffects = const [],
  }) : super(
    mediaType: 'adjustment',
    isAdjustmentLayer: true,
  );

  factory AdjustmentLayer.create({
    required double startTime,
    required double endTime,
    ColorGrade? colorGrade,
    List<Effect>? effects,
  }) => AdjustmentLayer(
    id: _uuid.v4(),
    startTime: startTime,
    endTime: endTime,
    adjustmentColorGrade: colorGrade ?? const ColorGrade(),
    adjustmentEffects: effects ?? [],
  );

  @override
  AdjustmentLayer copyWith({
    String? id,
    double? startTime,
    double? endTime,
    double? trimStart,
    double? trimEnd,
    double? fadeIn,
    double? fadeOut,
    String? mediaPath,
    String? mediaType,
    double? speed,
    bool? isReversed,
    bool? isAdjustmentLayer,
    bool? isTextLayer,
    List<Effect>? effects,
    List<Keyframe>? keyframes,
    KeyframeAnimation? animation,
    BlendMode? blendMode,
    double? opacity,
    Transform3D? transform,
    ColorGrade? colorGrade,
    Transition? transitionIn,
    Transition? transitionOut,
    bool? isMuted,
    double? volume,
    String? textContent,
    Map<String, dynamic>? textStyle,
    ChromaKey? chromaKey,
    Mask? mask,
    AudioEnvelope? audioEnvelope,
    bool? noiseReduction,
    AdvancedColorGrade? advancedColorGrade,
    MotionTrack? motionTrack,
    ParticleEffect? particleEffect,
    List<AutoCaption>? autoCaptions,
    // Adjustment specific
    ColorGrade? adjustmentColorGrade,
    List<Effect>? adjustmentEffects,
  }) =>
      AdjustmentLayer(
        id: id ?? this.id,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        adjustmentColorGrade: adjustmentColorGrade ?? colorGrade ?? this.adjustmentColorGrade,
        adjustmentEffects: adjustmentEffects ?? effects ?? this.adjustmentEffects,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'isAdjustmentLayer': true,
    'adjustmentColorGrade': adjustmentColorGrade.toJson(),
    'adjustmentEffects': adjustmentEffects.map((e) => e.toJson()).toList(),
  };

  factory AdjustmentLayer.fromJson(Map<String, dynamic> j) {
    final base = Clip.fromJson(j);
    return AdjustmentLayer(
      id: base.id,
      startTime: base.startTime,
      endTime: base.endTime,
      adjustmentColorGrade: j['adjustmentColorGrade'] != null
          ? ColorGrade.fromJson(j['adjustmentColorGrade'])
          : const ColorGrade(),
      adjustmentEffects: j['adjustmentEffects'] != null
          ? (j['adjustmentEffects'] as List).map((e) => Effect.fromJson(e)).toList()
          : [],
    );
  }

  @override
  List<Object?> get props => [...super.props, adjustmentColorGrade, adjustmentEffects];
}

// ─────────────────────────────────────────────────────────────────────────────
// AUDIO MIX
// ─────────────────────────────────────────────────────────────────────────────

class AudioMix extends Equatable {
  final double masterVolume;
  final bool muteAll;

  const AudioMix({this.masterVolume = 1.0, this.muteAll = false});
  Map<String, dynamic> toJson() => {'masterVolume': masterVolume, 'muteAll': muteAll};
  factory AudioMix.fromJson(Map<String, dynamic> j) => AudioMix(masterVolume: j['masterVolume'] ?? 1.0, muteAll: j['muteAll'] ?? false);

  @override
  List<Object?> get props => [masterVolume, muteAll];
}

// ─────────────────────────────────────────────────────────────────────────────
// TRACK
// ─────────────────────────────────────────────────────────────────────────────

class Track extends Equatable {
  final String id;
  final String name;
  final TrackType type;
  final int zIndex;
  final bool isLocked;
  final bool isSolo;
  final bool isMuted;
  final bool isCollapsed;
  final List<Clip> clips;

  const Track({
    required this.id,
    required this.name,
    required this.type,
    required this.zIndex,
    this.isLocked = false,
    this.isSolo = false,
    this.isMuted = false,
    this.isCollapsed = false,
    this.clips = const [],
  });

  factory Track.create({required String name, required TrackType type, required int zIndex}) =>
      Track(id: _uuid.v4(), name: name, type: type, zIndex: zIndex);

  Clip? clipAt(double time) {
    for (final clip in clips) {
      if (time >= clip.startTime && time < clip.endTime) return clip;
    }
    return null;
  }

  Track copyWith({
    String? id,
    String? name, TrackType? type, int? zIndex, bool? isLocked,
    bool? isSolo, bool? isMuted, bool? isCollapsed, List<Clip>? clips,
  }) => Track(
    id: id ?? this.id, name: name ?? this.name, type: type ?? this.type, zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked ?? this.isLocked, isSolo: isSolo ?? this.isSolo,
    isMuted: isMuted ?? this.isMuted, isCollapsed: isCollapsed ?? this.isCollapsed,
    clips: clips ?? this.clips,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'type': type.name, 'zIndex': zIndex,
    'isLocked': isLocked, 'isSolo': isSolo, 'isMuted': isMuted, 'isCollapsed': isCollapsed,
    'clips': clips.map((c) => c.toJson()).toList(),
  };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
    id: j['id'], name: j['name'], type: TrackType.values.byName(j['type']),
    zIndex: j['zIndex'], isLocked: j['isLocked'] ?? false, isSolo: j['isSolo'] ?? false,
    isMuted: j['isMuted'] ?? false, isCollapsed: j['isCollapsed'] ?? false,
    clips: (j['clips'] as List? ?? [])
        .map((c) => Clip.fromJsonPolymorphic(c))
        .toList(),
  );

  @override
  List<Object?> get props => [id, name, type, zIndex, clips];
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOLUTION
// ─────────────────────────────────────────────────────────────────────────────

class Resolution extends Equatable {
  final int width;
  final int height;
  final int frameRate;

  const Resolution({required this.width, required this.height, this.frameRate = 30});

  static const p720 = Resolution(width: 1280, height: 720);
  static const p1080 = Resolution(width: 1920, height: 1080);
  static const p4k = Resolution(width: 3840, height: 2160);
  static const vertical9x16 = Resolution(width: 1080, height: 1920);
  static const square1x1 = Resolution(width: 1080, height: 1080);

  static List<Resolution> get values => [p720, p1080, p4k, vertical9x16, square1x1];

  double get aspectRatio => width / height;
  String get label => '${width}x$height';

  Map<String, dynamic> toJson() => {'width': width, 'height': height, 'frameRate': frameRate};
  factory Resolution.fromJson(Map<String, dynamic> j) => Resolution(width: j['width'], height: j['height'], frameRate: j['frameRate'] ?? 30);

  @override
  List<Object?> get props => [width, height, frameRate];
}

class ProjectAsset extends Equatable {
  final String id;
  final String name;
  final String path;
  final String type; // 'video', 'image', 'audio'
  final String? thumbnailPath;
  final double? duration;

  const ProjectAsset({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.thumbnailPath,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'type': type,
        'thumbnailPath': thumbnailPath,
        'duration': duration,
      };

  factory ProjectAsset.fromJson(Map<String, dynamic> j) => ProjectAsset(
        id: j['id'],
        name: j['name'],
        path: j['path'],
        type: j['type'],
        thumbnailPath: j['thumbnailPath'],
        duration: j['duration'],
      );

  @override
  List<Object?> get props => [id, path];
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO PROJECT
// ─────────────────────────────────────────────────────────────────────────────

class VideoProject extends Equatable {
  final String id;
  final String name;
  final double duration;
  final Resolution resolution;
  final List<Track> tracks;
  final List<ProjectAsset> assets;
  final AudioMix audioMix;
  final ColorGrade globalColorGrade;
  final ProjectStatus status;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final String? templateId;
  final BeatTrack? beatTrack;

  const VideoProject({
    required this.id,
    required this.name,
    this.duration = 0,
    this.resolution = Resolution.p1080,
    this.tracks = const [],
    this.assets = const [],
    this.audioMix = const AudioMix(),
    this.globalColorGrade = const ColorGrade(),
    this.status = ProjectStatus.draft,
    this.thumbnailPath,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.templateId,
    this.beatTrack,
  });

  factory VideoProject.create({String name = 'Untitled Project', Resolution? resolution}) {
    final now = DateTime.now();
    return VideoProject(
      id: _uuid.v4(), name: name,
      resolution: resolution ?? Resolution.p1080,
      createdAt: now, updatedAt: now,
    );
  }

  double get computedDuration {
    if (tracks.isEmpty) return 0;
    double max = 0;
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.endTime > max) max = clip.endTime;
      }
    }
    return max;
  }

  VideoProject copyWith({
    String? id,
    String? name,
    double? duration,
    Resolution? resolution,
    List<Track>? tracks,
    List<ProjectAsset>? assets,
    AudioMix? audioMix,
    ColorGrade? globalColorGrade,
    ProjectStatus? status,
    String? thumbnailPath,
    DateTime? updatedAt,
    BeatTrack? beatTrack,
  }) =>
      VideoProject(
        id: id ?? this.id,
        name: name ?? this.name,
        duration: duration ?? this.duration,
        resolution: resolution ?? this.resolution,
        tracks: tracks ?? this.tracks,
        assets: assets ?? this.assets,
        audioMix: audioMix ?? this.audioMix,
        globalColorGrade: globalColorGrade ?? this.globalColorGrade,
        status: status ?? this.status,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        userId: userId,
        templateId: templateId,
        beatTrack: beatTrack ?? this.beatTrack,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'duration': duration,
        'resolution': resolution.toJson(),
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'assets': assets.map((a) => a.toJson()).toList(),
        'audioMix': audioMix.toJson(),
        'globalColorGrade': globalColorGrade.toJson(),
        'status': status.name,
        'thumbnailPath': thumbnailPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'userId': userId,
        'templateId': templateId,
        'beatTrack': beatTrack?.toJson(),
      };

  factory VideoProject.fromJson(Map<String, dynamic> j) => VideoProject(
        id: j['id'],
        name: j['name'],
        duration: j['duration'] ?? 0,
        resolution: Resolution.fromJson(j['resolution']),
        tracks: (j['tracks'] as List? ?? [])
            .map((t) => Track.fromJson(t))
            .toList(),
        assets: (j['assets'] as List? ?? [])
            .map((a) => ProjectAsset.fromJson(a))
            .toList(),
        audioMix: AudioMix.fromJson(j['audioMix'] ?? {}),
        globalColorGrade: ColorGrade.fromJson(j['globalColorGrade'] ?? {}),
        status: ProjectStatus.values.byName(j['status'] ?? 'draft'),
        thumbnailPath: j['thumbnailPath'],
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
        userId: j['userId'],
        templateId: j['templateId'],
        beatTrack: j['beatTrack'] != null ? BeatTrack.fromJson(j['beatTrack']) : null,
      );

  @override
  List<Object?> get props => [id, name, duration, resolution, tracks, status, updatedAt];
}
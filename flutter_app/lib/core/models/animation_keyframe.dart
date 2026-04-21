// lib/core/models/animation_keyframe.dart
import 'package:flutter/material.dart';

enum KeyframeType {
  position,
  scale,
  rotation,
  opacity,
  skew,
  anchor,
}

enum InterpolationType {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  bounce,
  elastic,
  step,
}

class AnimationKeyframe {
  final String id;
  final double time; // 0.0 to 1.0
  final KeyframeType type;
  final dynamic value;
  final InterpolationType interpolation;
  final Curve customCurve;
  final double? easeIntensity;

  const AnimationKeyframe({
    required this.id,
    required this.time,
    required this.type,
    required this.value,
    this.interpolation = InterpolationType.easeInOut,
    this.customCurve = Curves.easeInOut,
    this.easeIntensity,
  });

  factory AnimationKeyframe.create({
    required double time,
    required KeyframeType type,
    required dynamic value,
    InterpolationType interpolation = InterpolationType.easeInOut,
    double? easeIntensity,
  }) {
    return AnimationKeyframe(
      id: DateTime.now().millisecondsSinceEpoch.toString() + 
           (type.index.toString()),
      time: time.clamp(0.0, 1.0),
      type: type,
      value: value,
      interpolation: interpolation,
      easeIntensity: easeIntensity,
    );
  }

  Curve get curve {
    switch (interpolation) {
      case InterpolationType.linear:
        return Curves.linear;
      case InterpolationType.easeIn:
        return Curves.easeIn;
      case InterpolationType.easeOut:
        return Curves.easeOut;
      case InterpolationType.easeInOut:
        return Curves.easeInOut;
      case InterpolationType.bounce:
        return Curves.bounceOut;
      case InterpolationType.elastic:
        return Curves.elasticOut;
      case InterpolationType.step:
        return Curves.linear; // Step curve is not directly available in standard Curves, using linear as fallback or should implement custom
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'type': type.index,
    'value': _valueToJson(value),
    'interpolation': interpolation.index,
    'easeIntensity': easeIntensity,
  };

  factory AnimationKeyframe.fromJson(Map<String, dynamic> json) {
    return AnimationKeyframe(
      id: json['id'],
      time: json['time'],
      type: KeyframeType.values[json['type']],
      value: _valueFromJson(json['value'], KeyframeType.values[json['type']]),
      interpolation: InterpolationType.values[json['interpolation'] ?? 3],
      easeIntensity: json['easeIntensity'],
    );
  }

  static dynamic _valueToJson(dynamic value) {
    if (value is Offset) return {'dx': value.dx, 'dy': value.dy};
    if (value is double) return value;
    if (value is Alignment) return {'x': value.x, 'y': value.y};
    return value;
  }

  static dynamic _valueFromJson(dynamic json, KeyframeType type) {
    switch (type) {
      case KeyframeType.position:
        return Offset(json['dx'] as double, json['dy'] as double);
      case KeyframeType.anchor:
        return Alignment(json['x'] as double, json['y'] as double);
      case KeyframeType.scale:
      case KeyframeType.rotation:
      case KeyframeType.opacity:
      case KeyframeType.skew:
        return json as double;
    }
  }

  AnimationKeyframe copyWith({
    double? time,
    dynamic value,
    InterpolationType? interpolation,
  }) {
    return AnimationKeyframe(
      id: id,
      time: time ?? this.time,
      type: type,
      value: value ?? this.value,
      interpolation: interpolation ?? this.interpolation,
      customCurve: customCurve,
      easeIntensity: easeIntensity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimationKeyframe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class KeyframeAnimation {
  final String id;
  final String name;
  final List<AnimationKeyframe> keyframes;
  final bool isLooping;
  final double duration; // seconds, null means auto from clip

  const KeyframeAnimation({
    required this.id,
    this.name = 'Animation',
    required this.keyframes,
    this.isLooping = false,
    this.duration = 0,
  });

  factory KeyframeAnimation.create({String name = 'Animation'}) {
    return KeyframeAnimation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      keyframes: [],
    );
  }

  bool get hasKeyframes => keyframes.isNotEmpty;
  
  double get maxTime {
    if (keyframes.isEmpty) return 0;
    return keyframes.map((k) => k.time).reduce((a, b) => a > b ? a : b);
  }

  List<AnimationKeyframe> getKeyframesByType(KeyframeType type) {
    return keyframes.where((k) => k.type == type).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  dynamic getValueAtTime(double time, KeyframeType type) {
    final frames = getKeyframesByType(type);
    if (frames.isEmpty) return null;
    if (frames.length == 1) return frames.first.value;
    
    // Handle looping
    double normalizedTime = time;
    if (isLooping && time > maxTime) {
      normalizedTime = time % maxTime;
    }
    
    // Find surrounding keyframes
    AnimationKeyframe? prev;
    AnimationKeyframe? next;
    
    for (final frame in frames) {
      if (frame.time <= normalizedTime) prev = frame;
      if (frame.time >= normalizedTime && next == null) next = frame;
    }
    
    if (prev == null) return frames.first.value;
    if (next == null) return prev.value;
    if (prev.time == next.time) return prev.value;
    
    // Calculate interpolation
    final t = (normalizedTime - prev.time) / (next.time - prev.time);
    final curvedT = prev.curve.transform(t.clamp(0.0, 1.0));
    
    return _interpolateValues(prev.value, next.value, curvedT, type);
  }

  dynamic _interpolateValues(dynamic from, dynamic to, double t, KeyframeType type) {
    switch (type) {
      case KeyframeType.position:
        final p1 = from as Offset;
        final p2 = to as Offset;
        return Offset(
          p1.dx + (p2.dx - p1.dx) * t,
          p1.dy + (p2.dy - p1.dy) * t,
        );
      case KeyframeType.anchor:
        final a1 = from as Alignment;
        final a2 = to as Alignment;
        return Alignment(
          a1.x + (a2.x - a1.x) * t,
          a1.y + (a2.y - a1.y) * t,
        );
      case KeyframeType.scale:
      case KeyframeType.rotation:
      case KeyframeType.opacity:
      case KeyframeType.skew:
        final v1 = from as double;
        final v2 = to as double;
        return v1 + (v2 - v1) * t;
    }
  }

  // Get transform matrix for Native Engine
  Map<String, dynamic> toNativeFilter(double time, Size sourceSize, Size targetSize) {
    final position = getValueAtTime(time, KeyframeType.position) as Offset?;
    final scale = getValueAtTime(time, KeyframeType.scale) as double? ?? 1.0;
    final rotation = getValueAtTime(time, KeyframeType.rotation) as double? ?? 0;
    final opacity = getValueAtTime(time, KeyframeType.opacity) as double? ?? 1.0;
    
    final params = <String, dynamic>{};
    
    if (rotation != 0) {
      params['rotation'] = rotation;
    }
    
    if (scale != 1.0) {
      params['scale'] = scale;
    }
    
    if (position != null) {
      params['position'] = {'x': position.dx, 'y': position.dy};
    }
    
    if (opacity < 1.0) {
      params['opacity'] = opacity;
    }
    
    return params;
  }

  KeyframeAnimation addKeyframe(AnimationKeyframe keyframe) {
    final newKeyframes = [...keyframes, keyframe];
    return KeyframeAnimation(
      id: id,
      name: name,
      keyframes: newKeyframes,
      isLooping: isLooping,
      duration: duration,
    );
  }

  KeyframeAnimation removeKeyframe(String keyframeId) {
    final newKeyframes = keyframes.where((k) => k.id != keyframeId).toList();
    return KeyframeAnimation(
      id: id,
      name: name,
      keyframes: newKeyframes,
      isLooping: isLooping,
      duration: duration,
    );
  }

  KeyframeAnimation updateKeyframe(AnimationKeyframe keyframe) {
    final index = keyframes.indexWhere((k) => k.id == keyframe.id);
    if (index == -1) return this;
    
    final newKeyframes = List<AnimationKeyframe>.from(keyframes);
    newKeyframes[index] = keyframe;
    
    return KeyframeAnimation(
      id: id,
      name: name,
      keyframes: newKeyframes,
      isLooping: isLooping,
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'keyframes': keyframes.map((k) => k.toJson()).toList(),
    'isLooping': isLooping,
    'duration': duration,
  };

  factory KeyframeAnimation.fromJson(Map<String, dynamic> json) {
    return KeyframeAnimation(
      id: json['id'],
      name: json['name'] ?? 'Animation',
      keyframes: (json['keyframes'] as List)
          .map((k) => AnimationKeyframe.fromJson(k as Map<String, dynamic>))
          .toList(),
      isLooping: json['isLooping'] ?? false,
      duration: json['duration'] ?? 0,
    );
  }

  KeyframeAnimation copyWith({
    String? name,
    bool? isLooping,
    double? duration,
  }) {
    return KeyframeAnimation(
      id: id,
      name: name ?? this.name,
      keyframes: keyframes,
      isLooping: isLooping ?? this.isLooping,
      duration: duration ?? this.duration,
    );
  }
}
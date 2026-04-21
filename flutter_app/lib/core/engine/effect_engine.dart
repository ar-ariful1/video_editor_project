enum EffectType { brightness, contrast, saturation, vignette, blur, sharpen }

class VideoEffect {
  final EffectType type;
  double intensity;

  VideoEffect({
    required this.type,
    this.intensity = 1.0,
  });
}

class EffectEngine {
  Map<String, double> getEffectParams(List<VideoEffect> effects) {
    final Map<String, double> params = {};
    for (var effect in effects) {
      params[effect.type.toString().split('.').last] = effect.intensity;
    }
    return params;
  }

  // Linear mapping for UI sliders to shader uniforms
  double mapIntensity(EffectType type, double value) {
    switch (type) {
      case EffectType.brightness: return value * 2.0 - 1.0; // -1.0 to 1.0
      case EffectType.contrast: return value * 2.0;       // 0.0 to 2.0
      case EffectType.saturation: return value * 2.0;     // 0.0 to 2.0
      default: return value;
    }
  }
}

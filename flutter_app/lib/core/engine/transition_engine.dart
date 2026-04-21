enum TransitionType { fade, slide, zoom, blur }

class TransitionConfig {
  final TransitionType type;
  final double durationUs;
  final String? customShaderPath;

  TransitionConfig({
    required this.type,
    required this.durationUs,
    this.customShaderPath,
  });
}

class TransitionEngine {
  double calculateProgress(double currentTimeUs, double transitionStartTimeUs, double durationUs) {
    if (currentTimeUs < transitionStartTimeUs) return 0.0;
    if (currentTimeUs > transitionStartTimeUs + durationUs) return 1.0;
    
    return (currentTimeUs - transitionStartTimeUs) / durationUs;
  }

  String getShaderName(TransitionType type) {
    switch (type) {
      case TransitionType.fade: return "fade";
      case TransitionType.slide: return "slide";
      case TransitionType.zoom: return "zoom";
      case TransitionType.blur: return "blur";
    }
  }
}

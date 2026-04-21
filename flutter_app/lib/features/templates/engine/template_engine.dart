// lib/features/templates/engine/template_engine.dart
// Full template engine — JSON schema v2, media binding, auto-duration, 2026 edition

import 'package:uuid/uuid.dart';
import '../../../core/models/video_project.dart';

const _uuid = Uuid();

class TemplateSlot {
  final String id, label, type;
  final double startTime, endTime;
  final String? transition;
  final double transitionDuration;
  final Map<String, dynamic> effects;

  const TemplateSlot(
      {required this.id,
      required this.label,
      required this.type,
      required this.startTime,
      required this.endTime,
      this.transition,
      this.transitionDuration = 0.4,
      this.effects = const {}});

  factory TemplateSlot.fromJson(Map<String, dynamic> j) => TemplateSlot(
        id: j['id'] ?? _uuid.v4(),
        label: j['label'] ?? 'Clip',
        type: j['type'] ?? 'image_or_video',
        startTime: (j['startTime'] as num? ?? 0).toDouble(),
        endTime: (j['endTime'] as num? ?? 3).toDouble(),
        transition: j['transition'],
        transitionDuration:
            (j['transitionDuration'] as num?)?.toDouble() ?? 0.4,
        effects: Map<String, dynamic>.from(j['effects'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'startTime': startTime,
        'endTime': endTime,
        'transition': transition,
        'transitionDuration': transitionDuration,
        'effects': effects
      };
}

class TemplateTextLayer {
  final String id, defaultText;
  final bool editable;
  final double startTime, endTime;
  final Map<String, dynamic> style;

  const TemplateTextLayer(
      {required this.id,
      required this.defaultText,
      required this.editable,
      required this.startTime,
      required this.endTime,
      required this.style});

  factory TemplateTextLayer.fromJson(Map<String, dynamic> j) =>
      TemplateTextLayer(
        id: j['id'] ?? _uuid.v4(),
        defaultText: j['defaultText'] ?? '',
        editable: j['editable'] ?? true,
        startTime: (j['startTime'] as num? ?? 0).toDouble(),
        endTime: (j['endTime'] as num? ?? 3).toDouble(),
        style: Map<String, dynamic>.from(j['style'] ?? {}),
      );
}

class TemplateDefinition {
  final String id, name, category, aspectRatio;
  final double duration;
  final bool isPremium;
  final List<TemplateSlot> slots;
  final List<TemplateTextLayer> textLayers;
  final List<Map<String, dynamic>> audioLayers;
  final Map<String, dynamic> colorGrade;

  const TemplateDefinition(
      {required this.id,
      required this.name,
      required this.category,
      required this.aspectRatio,
      required this.duration,
      required this.isPremium,
      required this.slots,
      required this.textLayers,
      this.audioLayers = const [],
      this.colorGrade = const {}});

  factory TemplateDefinition.fromJson(Map<String, dynamic> j) =>
      TemplateDefinition(
        id: j['id'] ?? _uuid.v4(),
        name: j['name'] ?? 'Template',
        category: j['category'] ?? 'general',
        aspectRatio: j['aspect_ratio'] ?? '9:16',
        duration: (j['duration'] as num? ?? 15).toDouble(),
        isPremium: j['is_premium'] ?? false,
        slots: ((j['slots'] ?? []) as List)
            .map((s) => TemplateSlot.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
        textLayers: ((j['text_layers'] ?? []) as List)
            .map(
                (t) => TemplateTextLayer.fromJson(Map<String, dynamic>.from(t)))
            .toList(),
        audioLayers: List<Map<String, dynamic>>.from(j['audio_layers'] ?? []),
        colorGrade: Map<String, dynamic>.from(j['color_grade'] ?? {}),
      );

  Resolution get resolution {
    switch (aspectRatio) {
      case '16:9':
        return const Resolution(width: 1920, height: 1080, frameRate: 30);
      case '1:1':
        return const Resolution(width: 1080, height: 1080, frameRate: 30);
      case '4:5':
        return const Resolution(width: 1080, height: 1350, frameRate: 30);
      default:
        return const Resolution(width: 1080, height: 1920, frameRate: 30);
    }
  }
}

class TemplateInjectionResult {
  final VideoProject project;
  final List<String> warnings;
  const TemplateInjectionResult(
      {required this.project, this.warnings = const []});
}

class TemplateEngine {
  static TemplateInjectionResult inject({
    required TemplateDefinition template,
    required Map<String, String> mediaPaths,
    required Map<String, String> textOverrides,
    required String projectName,
  }) {
    final warnings = <String>[];
    final videoClips = <Clip>[];
    double timeOffset = 0;

    for (final slot in template.slots) {
      final path = mediaPaths[slot.id];
      if (path == null) {
        warnings.add('No media for "${slot.label}"');
        continue;
      }
      final dur = slot.endTime - slot.startTime;
      videoClips.add(Clip(
        id: _uuid.v4(),
        startTime: timeOffset,
        endTime: timeOffset + dur,
        mediaPath: path,
        mediaType: slot.type == 'image' ? 'image' : 'video',
        trimStart: 0,
        volume: 1.0,
        fadeIn: 0,
        fadeOut: slot.transition != null ? slot.transitionDuration / 2 : 0,
        transitionOut: slot.transition != null
            ? Transition(
                type: slot.transition!, duration: slot.transitionDuration)
            : null,
        effects: slot.effects.entries
            .map((e) => Effect(
                id: _uuid.v4(),
                type: e.key,
                params: e.value is Map
                    ? Map<String, dynamic>.from(e.value as Map)
                    : {'intensity': e.value}))
            .toList(),
        keyframes: [],
      ));
      timeOffset += dur;
    }

    final totalDuration = timeOffset > 0 ? timeOffset : template.duration;

    final textClips = template.textLayers
        .map((tl) => Clip(
              id: _uuid.v4(),
              startTime: tl.startTime,
              endTime: tl.endTime,
              mediaType: 'text',
              textContent: textOverrides[tl.id] ?? tl.defaultText,
              textStyle: tl.style,
              keyframes: [],
            ))
        .toList();

    final audioClips = template.audioLayers
        .where((a) => (a['audioUrl'] ?? '').isNotEmpty)
        .map((a) => Clip(
              id: _uuid.v4(),
              startTime: (a['startTime'] as num?)?.toDouble() ?? 0,
              endTime: totalDuration,
              mediaPath: a['audioUrl'],
              mediaType: 'audio',
              volume: (a['volume'] as num?)?.toDouble() ?? 1.0,
              keyframes: [],
            ))
        .toList();

    final tracks = <Track>[
      if (videoClips.isNotEmpty)
        Track(
            id: _uuid.v4(),
            name: 'Video',
            type: TrackType.video,
            zIndex: 1,
            clips: videoClips),
      if (textClips.isNotEmpty)
        Track(
            id: _uuid.v4(),
            name: 'Text',
            type: TrackType.text,
            zIndex: 10,
            clips: textClips),
      if (audioClips.isNotEmpty)
        Track(
            id: _uuid.v4(),
            name: 'Music',
            type: TrackType.audio,
            zIndex: 2,
            clips: audioClips),
    ];

    return TemplateInjectionResult(
      project: VideoProject(
          id: _uuid.v4(),
          name: projectName,
          duration: totalDuration,
          resolution: template.resolution,
          tracks: tracks,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          templateId: template.id),
      warnings: warnings,
    );
  }

  // Generate template JSON from a user project
  static Map<String, dynamic> toJson(VideoProject project,
      {required String name,
      required String category,
      bool isPremium = false}) {
    final vt = project.tracks.firstWhere((t) => t.type == TrackType.video,
        orElse: () => project.tracks.first);
    final tt =
        project.tracks.where((t) => t.type == TrackType.text).firstOrNull;
    final at =
        project.tracks.where((t) => t.type == TrackType.audio).firstOrNull;

    return {
      'schema_version': 2,
      'id': _uuid.v4(),
      'name': name,
      'category': category,
      'aspect_ratio':
          '${project.resolution.width}:${project.resolution.height}',
      'duration': project.computedDuration,
      'frame_rate': project.resolution.frameRate,
      'is_premium': isPremium,
      'slots': vt.clips
          .asMap()
          .entries
          .map((e) => ({
                'id': 'slot_${e.key + 1}',
                'label': 'Clip ${e.key + 1}',
                'type': 'image_or_video',
                'startTime': e.value.startTime,
                'endTime': e.value.endTime,
                'transition': e.value.transitionOut?.type,
                'transitionDuration': e.value.transitionOut?.duration ?? 0.4,
                'effects': {
                  for (final fx in e.value.effects) fx.type: fx.params
                },
              }))
          .toList(),
      'text_layers': tt?.clips
              .map((c) => ({
                    'id': c.id,
                    'defaultText': c.textContent ?? '',
                    'editable': true,
                    'startTime': c.startTime,
                    'endTime': c.endTime,
                    'style': c.textStyle ?? {}
                  }))
              .toList() ??
          [],
      'audio_layers': at?.clips
              .map((c) => ({
                    'id': c.id,
                    'audioUrl': c.mediaPath ?? '',
                    'volume': c.volume,
                    'loop': true
                  }))
              .toList() ??
          [],
      'color_grade': {},
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

extension _ListExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

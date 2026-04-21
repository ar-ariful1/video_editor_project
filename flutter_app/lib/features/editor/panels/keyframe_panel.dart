// lib/features/editor/panels/keyframe_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../app_theme.dart';
import '../widgets/curve_editor.dart';

class KeyframePanel extends StatefulWidget {
  const KeyframePanel({super.key});
  @override
  State<KeyframePanel> createState() => _KeyframePanelState();
}

class _KeyframePanelState extends State<KeyframePanel> {
  String _selectedProp = 'opacity';

  static const _properties = [
    ('opacity', '⬜', 'Opacity', 0.0, 1.0),
    ('x', '↔️', 'Position X', -1.0, 1.0),
    ('y', '↕️', 'Position Y', -1.0, 1.0),
    ('scaleX', '⟺', 'Scale X', 0.1, 4.0),
    ('scaleY', '⟳', 'Scale Y', 0.1, 4.0),
    ('rotation', '🔄', 'Rotation', -180.0, 180.0),
    ('blur', '🌫️', 'Blur', 0.0, 20.0),
    ('brightness', '☀️', 'Brightness', -100.0, 100.0),
    ('saturation', '🎨', 'Saturation', -100.0, 100.0),
    ('skewX', '⟋', 'Skew X', -45.0, 45.0),
    ('skewY', '⟍', 'Skew Y', -45.0, 45.0),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (ctx, state) {
        final clip = _getSelectedClip(state);
        final propKeyframes = clip?.keyframes
                .where((k) => k.property == _selectedProp)
                .toList() ??
            [];
        final propInfo = _properties.firstWhere((p) => p.$1 == _selectedProp,
            orElse: () => _properties.first);

        return Column(children: [
          // Property selector
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: _properties.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final p = _properties[i];
                final selected = _selectedProp == p.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedProp = p.$1),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accent.withValues(alpha: 0.2)
                          : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Row(children: [
                      Text(p.$2, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(p.$3,
                          style: TextStyle(
                              color: selected
                                  ? AppTheme.accent
                                  : AppTheme.textTertiary,
                              fontSize: 11)),
                    ]),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add keyframe button
                    Row(children: [
                      Expanded(
                        child: Text(
                          '${propInfo.$3} keyframes',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: clip == null
                            ? null
                            : () => _addKeyframe(ctx, state, clip, propInfo),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Keyframe',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    if (clip != null && propKeyframes.isNotEmpty) ...[
                      // Current value slider for the selected property at current playhead
                      _buildValueSlider(ctx, state, clip, propInfo),
                      const SizedBox(height: 16),
                      CurveEditor(
                        bezierHandles: const [0.42, 0.0, 0.58, 1.0],
                        onChanged: (c) {
                          // Update all keyframes or current segment with this curve
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.border),
                      const SizedBox(height: 12),
                    ],

                    if (clip == null)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Select a clip on the timeline',
                            style: TextStyle(color: AppTheme.textTertiary)),
                      ))
                    else if (propKeyframes.isEmpty)
                      Center(
                          child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          const Icon(Icons.linear_scale,
                              color: AppTheme.textTertiary, size: 36),
                          const SizedBox(height: 8),
                          Text('No ${propInfo.$3} keyframes yet',
                              style: const TextStyle(
                                  color: AppTheme.textTertiary)),
                          const SizedBox(height: 4),
                          const Text('Move playhead and tap "Add at Playhead"',
                              style: TextStyle(
                                  color: AppTheme.textTertiary, fontSize: 11)),
                        ]),
                      ))
                    else
                      // Keyframe list
                      ...propKeyframes.map((kf) => _KeyframeRow(
                            keyframe: kf,
                            propInfo: propInfo,
                            onDelete: () =>
                                ctx.read<TimelineBloc>().add(RemoveKeyframe(
                                      trackId: _getTrackId(state, clip)!,
                                      clipId: clip.id,
                                      keyframeId: kf.id,
                                    )),
                            onEasingChange: (easing) {
                              final updated = kf.copyWith(easing: easing);
                              // Replace keyframe
                              ctx.read<TimelineBloc>().add(AddKeyframe(
                                    trackId: _getTrackId(state, clip)!,
                                    clipId: clip.id,
                                    keyframe: updated,
                                  ));
                            },
                          )),

                    if (propKeyframes.length >= 2) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Row(children: [
                          Icon(Icons.info_outline,
                              color: AppTheme.accent, size: 14),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'Flutter will interpolate between keyframes automatically.',
                                  style: TextStyle(
                                      color: AppTheme.accent, fontSize: 11))),
                        ]),
                      ),
                    ],
                  ]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildValueSlider(BuildContext ctx, TimelineState state, Clip clip, dynamic propInfo) {
    final prop = propInfo.$1;
    final min = propInfo.$4 as double;
    final max = propInfo.$5 as double;

    // Find if there's a keyframe exactly at current playhead (relative to clip)
    final relativeTime = state.currentTime - clip.startTime;
    final existingKf = clip.keyframes.firstWhereOrNull(
      (k) => k.property == prop && (k.time - relativeTime).abs() < 0.05
    );

    double currentValue = existingKf?.value ?? _getInterpolatedValue(clip, prop, relativeTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Adjust ${propInfo.$3}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            Text(currentValue.toStringAsFixed(2), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: currentValue.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            final trackId = _getTrackId(state, clip);
            if (trackId == null) return;

            final newKf = Keyframe.create(
              time: relativeTime,
              property: prop,
              value: v,
            );

            ctx.read<TimelineBloc>().add(AddKeyframe(
              trackId: trackId,
              clipId: clip.id,
              keyframe: newKf,
            ));
          },
        ),
      ],
    );
  }

  double _getInterpolatedValue(Clip clip, String prop, double time) {
    return clip.getKeyframeValue(prop, time) ?? 1.0;
  }

  Clip? _getSelectedClip(TimelineState state) {
    for (final track in state.project?.tracks ?? []) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId) return clip;
      }
    }
    return null;
  }

  String? _getTrackId(TimelineState state, Clip clip) {
    for (final track in state.project?.tracks ?? []) {
      for (final c in track.clips) {
        if (c.id == clip.id) return track.id;
      }
    }
    return null;
  }

  void _addKeyframe(
      BuildContext ctx, TimelineState state, Clip clip, dynamic propInfo) {
    final trackId = _getTrackId(state, clip);
    if (trackId == null) return;

    // Default value based on property
    double defaultValue;
    switch (propInfo.$1) {
      case 'opacity':
        defaultValue = 1.0;
        break;
      case 'scaleX':
      case 'scaleY':
        defaultValue = 1.0;
        break;
      default:
        defaultValue = 0.0;
    }

    final kf = Keyframe.create(
      time: state.currentTime - clip.startTime, // relative to clip
      property: propInfo.$1,
      value: defaultValue,
    );

    ctx
        .read<TimelineBloc>()
        .add(AddKeyframe(trackId: trackId, clipId: clip.id, keyframe: kf));
  }
}

class _KeyframeRow extends StatelessWidget {
  final Keyframe keyframe;
  final dynamic propInfo;
  final VoidCallback onDelete;
  final ValueChanged<EasingType> onEasingChange;

  const _KeyframeRow(
      {required this.keyframe,
      required this.propInfo,
      required this.onDelete,
      required this.onEasingChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        // Time
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6)),
          child: Text(
            '${keyframe.time.toStringAsFixed(2)}s',
            style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 10),
        // Value
        Expanded(
            child: Text(
          '${propInfo.$3}: ${(keyframe.value as num).toStringAsFixed(2)}',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
        )),
        // Easing
        DropdownButton<EasingType>(
          value: keyframe.easing,
          dropdownColor: AppTheme.bg2,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          underline: const SizedBox.shrink(),
          items: EasingType.values
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.name,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ))
              .toList(),
          onChanged: (e) {
            if (e != null) onEasingChange(e);
          },
        ),
        // Delete
        IconButton(
          icon: const Icon(Icons.delete_outline,
              color: AppTheme.accent4, size: 18),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    );
  }
}


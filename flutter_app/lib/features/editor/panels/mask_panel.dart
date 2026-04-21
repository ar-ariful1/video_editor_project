// lib/features/editor/panels/mask_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

enum MaskType { linear, radial, mirror, freehand, rectangle, circle }

class MaskLayer {
  final String id;
  final MaskType type;
  final double x, y, width, height, rotation, feather;
  final bool inverted;
  const MaskLayer(
      {required this.id,
      required this.type,
      this.x = 0.5,
      this.y = 0.5,
      this.width = 0.5,
      this.height = 0.3,
      this.rotation = 0,
      this.feather = 0.1,
      this.inverted = false});
  MaskLayer copyWith(
          {MaskType? type,
          double? x,
          double? y,
          double? width,
          double? height,
          double? rotation,
          double? feather,
          bool? inverted}) =>
      MaskLayer(
          id: id,
          type: type ?? this.type,
          x: x ?? this.x,
          y: y ?? this.y,
          width: width ?? this.width,
          height: height ?? this.height,
          rotation: rotation ?? this.rotation,
          feather: feather ?? this.feather,
          inverted: inverted ?? this.inverted);
}

class MaskPanel extends StatefulWidget {
  const MaskPanel({super.key});
  @override
  State<MaskPanel> createState() => _MaskPanelState();
}

class _MaskPanelState extends State<MaskPanel> {
  MaskType _selectedType = MaskType.linear;
  List<MaskLayer> _masks = [];
  int _selectedMaskIdx = -1;

  static const _types = [
    (MaskType.linear, '▬', 'Linear'),
    (MaskType.radial, '⬤', 'Radial'),
    (MaskType.mirror, '⟺', 'Mirror'),
    (MaskType.rectangle, '▬', 'Rectangle'),
    (MaskType.circle, '◯', 'Circle'),
    (MaskType.freehand, '✏️', 'Freehand'),
  ];

  void _addMask() {
    final mask = MaskLayer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _selectedType,
    );
    setState(() {
      _masks.add(mask);
      _selectedMaskIdx = _masks.length - 1;
    });
    _syncWithBloc();
  }

  void _removeMask(int idx) {
    setState(() {
      _masks.removeAt(idx);
      _selectedMaskIdx = _masks.isEmpty ? -1 : _masks.length - 1;
    });
    _syncWithBloc();
  }

  MaskLayer? get _selected =>
      _selectedMaskIdx >= 0 && _selectedMaskIdx < _masks.length
          ? _masks[_selectedMaskIdx]
          : null;

  void _updateSelected(MaskLayer updated) {
    setState(() => _masks[_selectedMaskIdx] = updated);
    _syncWithBloc();
  }

  void _syncWithBloc() {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) return;

    final maskEffect = Effect.create(type: 'mask', params: {
      'masks': _masks.map((m) => {
        'type': m.type.name,
        'x': m.x,
        'y': m.y,
        'width': m.width,
        'height': m.height,
        'rotation': m.rotation,
        'feather': m.feather,
        'inverted': m.inverted,
      }).toList(),
    });

    for (final track in state.project?.tracks ?? []) {
      if (track.id == state.selectedTrackId) {
        for (final clip in track.clips) {
          if (clip.id == state.selectedClipId) {
            final otherEffects = clip.effects.where((e) => e.type != 'mask').toList();
            final updatedClip = clip.copyWith(effects: [...otherEffects, maskEffect]);
            bloc.add(UpdateClip(trackId: track.id, clip: updatedClip));
            return;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Mask type selector
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mask Type',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _types.map((t) {
                final sel = _selectedType == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t.$1),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sel ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.$2,
                          style: TextStyle(
                              color: sel
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                              fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(t.$3,
                          style: TextStyle(
                              color: sel
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                              fontSize: 11)),
                    ]),
                  ),
                );
              }).toList()),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addMask,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Mask'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ]),
      ),

      // Mask list
      if (_masks.isNotEmpty) ...[
        const Divider(height: 1, color: AppTheme.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              // Active masks
              ..._masks.asMap().entries.map((e) {
                final mask = e.value;
                final sel = _selectedMaskIdx == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMaskIdx = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          sel ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Row(children: [
                      Icon(_maskIcon(mask.type),
                          color: sel ? AppTheme.accent : AppTheme.textSecondary,
                          size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(mask.type.name,
                              style: TextStyle(
                                  color: sel
                                      ? AppTheme.accent
                                      : AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500))),
                      if (mask.inverted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppTheme.accent4.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('INV',
                              style: TextStyle(
                                  color: AppTheme.accent4,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                          onTap: () => _removeMask(e.key),
                          child: const Icon(Icons.delete_outline,
                              color: AppTheme.accent4, size: 16)),
                    ]),
                  ),
                );
              }),

              // Selected mask controls
              if (_selected != null) ...[
                const SizedBox(height: 8),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 12),
                const Text('Mask Properties',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _MaskSlider('X Position', _selected!.x, 0, 1,
                    (v) => _updateSelected(_selected!.copyWith(x: v))),
                _MaskSlider('Y Position', _selected!.y, 0, 1,
                    (v) => _updateSelected(_selected!.copyWith(y: v))),
                _MaskSlider('Width', _selected!.width, 0.1, 1,
                    (v) => _updateSelected(_selected!.copyWith(width: v))),
                _MaskSlider('Height', _selected!.height, 0.1, 1,
                    (v) => _updateSelected(_selected!.copyWith(height: v))),
                _MaskSlider('Rotation', _selected!.rotation, -180, 180,
                    (v) => _updateSelected(_selected!.copyWith(rotation: v))),
                _MaskSlider('Feather', _selected!.feather, 0, 1,
                    (v) => _updateSelected(_selected!.copyWith(feather: v))),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(
                      child: Text('Invert Mask',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13))),
                  Switch(
                      value: _selected!.inverted,
                      onChanged: (v) =>
                          _updateSelected(_selected!.copyWith(inverted: v))),
                ]),
                const SizedBox(height: 12),
              ],
            ]),
          ),
        ),
      ] else
        const Expanded(
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text('✂️', style: TextStyle(fontSize: 36)),
                SizedBox(height: 12),
                Text('No masks added',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                SizedBox(height: 4),
                Text('Select a type and tap Add Mask',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
              ])),
        ),
    ]);
  }

  IconData _maskIcon(MaskType t) {
    switch (t) {
      case MaskType.linear:
        return Icons.horizontal_rule_rounded;
      case MaskType.radial:
        return Icons.radio_button_unchecked_rounded;
      case MaskType.mirror:
        return Icons.compare_rounded;
      case MaskType.rectangle:
        return Icons.crop_square_rounded;
      case MaskType.circle:
        return Icons.circle_outlined;
      case MaskType.freehand:
        return Icons.gesture_rounded;
    }
  }
}

class _MaskSlider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _MaskSlider(this.label, this.value, this.min, this.max, this.onChanged);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11))),
          Expanded(
              child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6)),
                  child: Slider(
                      value: value.clamp(min, max),
                      min: min,
                      max: max,
                      onChanged: onChanged))),
          SizedBox(
              width: 40,
              child: Text(value.toStringAsFixed(2),
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 10),
                  textAlign: TextAlign.right)),
        ]),
      );
}

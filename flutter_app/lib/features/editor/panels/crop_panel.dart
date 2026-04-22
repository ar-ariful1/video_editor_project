// lib/features/editor/panels/crop_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/engine/native_engine_bridge.dart';

class CropPanel extends StatefulWidget {
  const CropPanel({super.key});
  @override
  State<CropPanel> createState() => _CropPanelState();
}

class _CropPanelState extends State<CropPanel> {
  String _ratio = 'free';
  double _rotation = 0;
  bool _flipH = false;
  bool _flipV = false;
  String _fitMode = 'fit'; // fit, fill, stretch
  double _zoom = 1.0;
  bool _showGrid = true;

  // Crop rectangle values (normalized 0..1)
  double _cropLeft = 0.0;
  double _cropTop = 0.0;
  double _cropWidth = 1.0;
  double _cropHeight = 1.0;

  static const _ratios = [
    ('free', 'Free', null),
    ('orig', 'Original', null),
    ('1:1', '1:1', 1.0),
    ('9:16', '9:16', 9 / 16),
    ('16:9', '16:9', 16 / 9),
    ('4:5', '4:5', 4 / 5),
    ('4:3', '4:3', 4 / 3),
    ('3:2', '3:2', 3 / 2),
    ('2.35:1', 'CineSc', 2.35),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Crop preview box
        Center(
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.bg3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent, width: 1.5),
            ),
            child: Stack(children: [
              Center(
                  child: Icon(Icons.crop_rounded,
                      color: AppTheme.accent.withValues(alpha: 0.4), size: 60)),
              // Corner handles
              ...[
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight
              ].map(
                (a) => Align(
                    alignment: a,
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 18),

        // Zoom Slider
        const Text('Zoom',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        Row(children: [
          const Icon(Icons.zoom_out_rounded, color: AppTheme.textTertiary, size: 18),
          Expanded(
              child: Slider(
            value: _zoom,
            min: 1.0,
            max: 3.0,
            onChanged: (v) => setState(() => _zoom = v),
          )),
          const Icon(Icons.zoom_in_rounded, color: AppTheme.textTertiary, size: 18),
        ]),
        const SizedBox(height: 18),

        // Fit/Fill/Stretch Options
        const Text('Fitting Mode',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _ModeBtn(
              label: 'Fit',
              active: _fitMode == 'fit',
              onTap: () => setState(() => _fitMode = 'fit')),
          const SizedBox(width: 8),
          _ModeBtn(
              label: 'Fill',
              active: _fitMode == 'fill',
              onTap: () => setState(() => _fitMode = 'fill')),
          const SizedBox(width: 8),
          _ModeBtn(
              label: 'Stretch',
              active: _fitMode == 'stretch',
              onTap: () => setState(() => _fitMode = 'stretch')),
        ]),
        const SizedBox(height: 18),

        // Aspect ratio presets
        const Text('Aspect Ratio',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _ratios.map((r) {
              final selected = _ratio == r.$1;
              return GestureDetector(
                onTap: () => setState(() => _ratio = r.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accent.withValues(alpha: 0.2)
                        : AppTheme.bg3,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Text(r.$2,
                      style: TextStyle(
                        color:
                            selected ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      )),
                ),
              );
            }).toList()),
        const SizedBox(height: 18),

        // Rotation
        const Text('Rotation',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        Row(children: [
          const Icon(Icons.rotate_left_rounded,
              color: AppTheme.textTertiary, size: 18),
          Expanded(
              child: Slider(
            value: _rotation,
            min: -180,
            max: 180,
            divisions: 360,
            onChanged: (v) => setState(() => _rotation = v),
          )),
          const Icon(Icons.rotate_right_rounded,
              color: AppTheme.textTertiary, size: 18),
        ]),
        Center(
            child: Text('${_rotation.toInt()}°',
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 12))),

        // Quick rotate buttons
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _QuickBtn(
              label: '↺ 90°',
              onTap: () => setState(() => _rotation = (_rotation - 90) % 360)),
          const SizedBox(width: 12),
          _QuickBtn(
              label: 'Reset',
              onTap: () => setState(() {
                    _rotation = 0;
                    _flipH = false;
                    _flipV = false;
                  })),
          const SizedBox(width: 12),
          _QuickBtn(
              label: '↻ 90°',
              onTap: () => setState(() => _rotation = (_rotation + 90) % 360)),
        ]),
        const SizedBox(height: 16),

        // Grid & Flip Tools
        Row(
          children: [
            const Text('Flip',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('Show Grid',
                style: TextStyle(
                    color: AppTheme.textTertiary, fontSize: 11)),
            Switch(
              value: _showGrid,
              onChanged: (v) => setState(() => _showGrid = v),
              activeColor: AppTheme.accent,
              scale: 0.7,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
              child: _FlipBtn(
            label: '↔ Horizontal',
            active: _flipH,
            onTap: () => setState(() => _flipH = !_flipH),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _FlipBtn(
            label: '↕ Vertical',
            active: _flipV,
            onTap: () => setState(() => _flipV = !_flipV),
          )),
        ]),
        const SizedBox(height: 18),

        // Apply
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _apply(context),
            icon: const Icon(Icons.crop_rounded),
            label: const Text('Apply Crop'),
          ),
        ),
      ]),
    );
  }

  void _apply(BuildContext context) {
    final state = context.read<TimelineBloc>().state;
    final clipId = state.selectedClipId;
    if (clipId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a clip first')),
      );
      return;
    }

    // Find the clip and its track
    for (final track in state.project?.tracks ?? []) {
      final clip = track.clips.firstWhereOrNull((c) => c.id == clipId);
      if (clip != null) {
        // Build the updated transform object
        final updatedTransform = clip.transform.copyWith(
          rotation: _rotation,
          scaleX: _zoom * (_flipH ? -1.0 : 1.0),
          scaleY: _zoom * (_flipV ? -1.0 : 1.0),
        );

        // Update the clip in the BLoC
        context.read<TimelineBloc>().add(UpdateClip(
          trackId: track.id,
          clip: clip.copyWith(
            transform: updatedTransform,
          ),
        ));

        // Also call native engine for crop
        final cropRect = Rect.fromLTWH(_cropLeft, _cropTop, _cropWidth, _cropHeight);
        NativeEngineBridge().setCrop(clipId, cropRect);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transform applied successfully')),
        );
        return;
      }
    }
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: AppTheme.bg3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border)),
          child: Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ),
      );
}

class _FlipBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FlipBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                active ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: active ? AppTheme.accent : AppTheme.border),
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: active ? AppTheme.accent : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400))),
        ),
      );
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.1)
                  : AppTheme.bg3,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: active ? AppTheme.accent : AppTheme.border),
            ),
            child: Center(
                child: Text(label,
                    style: TextStyle(
                        color:
                            active ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 11))),
          ),
        ),
      );
}
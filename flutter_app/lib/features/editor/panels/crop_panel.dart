// lib/features/editor/panels/crop_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../app_theme.dart';

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

        // Flip
        const Text('Flip',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
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
    if (state.selectedClipId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a clip first')),
      );
      return;
    }
    // Apply transform with rotation
    for (final track in state.project?.tracks ?? []) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId) {
          final updated = clip.copyWith(
            transform: clip.transform.copyWith(rotation: _rotation),
          );
          context
              .read<TimelineBloc>()
              .add(UpdateClip(trackId: track.id, clip: updated));
          return;
        }
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
            color: active ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
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


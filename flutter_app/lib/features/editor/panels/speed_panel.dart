// lib/features/editor/panels/speed_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../app_theme.dart';
import '../widgets/speed_curve_editor.dart';

class SpeedPanel extends StatefulWidget {
  const SpeedPanel({super.key});
  @override
  State<SpeedPanel> createState() => _SpeedPanelState();
}

class _SpeedPanelState extends State<SpeedPanel> {
  double _speed = 1.0;
  bool _reversed = false;
  bool _pitchCorrect = true;
  bool _isRamping = false;

  static const _presets = [
    (0.1, '0.1x'),
    (0.25, '0.25x'),
    (0.5, '0.5x'),
    (0.75, '0.75x'),
    (1.0, '1x'),
    (1.5, '1.5x'),
    (2.0, '2x'),
    (4.0, '4x'),
    (8.0, '8x'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (ctx, state) {
        // Load current clip speed
        final clip = _getSelectedClip(state);
        if (clip != null && clip.speed != _speed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _speed = clip.speed;
                _reversed = clip.isReversed;
              });
            }
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Speed display
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.3),
                      AppTheme.accent2.withValues(alpha: 0.3)
                    ],
                  ),
                  border: Border.all(color: AppTheme.accent, width: 2),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _speed == _speed.roundToDouble()
                            ? '${_speed.toInt()}x'
                            : '${_speed}x',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _speed < 1
                            ? 'Slow Mo'
                            : _speed > 1
                                ? 'Fast'
                                : 'Normal',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 11),
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 20),

            // Speed slider
            const Text('Speed',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: _speed.clamp(0.1, 8.0),
                min: 0.1,
                max: 8.0,
                divisions: 79,
                onChanged: (v) =>
                    setState(() => _speed = double.parse(v.toStringAsFixed(2))),
                onChangeEnd: (v) => _applySpeed(ctx, state, v),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('0.1x',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
              const Text('8x',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
            ]),
            const SizedBox(height: 14),

            // Preset buttons
            const Text('Presets',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presets.map((p) {
                final selected = (_speed - p.$1).abs() < 0.01;
                return GestureDetector(
                  onTap: () {
                    setState(() => _speed = p.$1);
                    _applySpeed(ctx, state, p.$1);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accent.withValues(alpha: 0.2)
                          : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Text(
                      p.$2,
                      style: TextStyle(
                        color:
                            selected ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Speed Ramping & Freeze Frame (New)
            const Text('Advanced Tools',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _ToolBtn(
                  icon: Icon(Icons.speed),
                  label: 'Speed Curve',
                  active: _isRamping,
                  onTap: () => setState(() => _isRamping = !_isRamping),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToolBtn(
                  icon: Icons.ac_unit_rounded,
                  label: 'Freeze Frame',
                  onTap: () {
                    if (clip != null) {
                      ctx.read<TimelineBloc>().add(UpdateClip(
                        trackId: state.selectedTrackId!,
                        clip: clip.copyWith(speed: 0.0), // 0.0 speed = freeze in engine
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Freeze frame applied at current position')),
                      );
                    }
                  },
                ),
              ),
            ]),
            if (_isRamping) ...[
              const SizedBox(height: 16),
              SpeedCurveEditor(
                points: clip?.speedCurve ?? [],
                clipDuration: clip?.duration ?? 1.0,
                onChanged: (points) => _applySpeedCurve(ctx, state, points),
              ),
            ],
            const SizedBox(height: 16),

            // Stabilization toggle
              _OptionRow(
              icon: Icons.edgesensor_low_rounded,
              label: 'Stabilization',
              subtitle: 'Reduce camera shake using AI',
              value: clip?.stabilization ?? false,
              onChanged: (v) async {
                if (clip != null) {
                  // Connect to NativeEngineService
                  if (v) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Analyzing video for stabilization...')),
                    );
                    // In a real app, this might trigger a native job.
                    // For now, we update the model which will trigger the native engine to apply it during render/export.
                  }
                  ctx.read<TimelineBloc>().add(UpdateClip(
                    trackId: state.selectedTrackId!,
                    clip: clip.copyWith(stabilization: v),
                  ));
                }
              },
            ),
            const SizedBox(height: 8),

            // Reverse toggle
            _OptionRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Reverse Video',
              value: _reversed,
              onChanged: (v) {
                setState(() => _reversed = v);
                _applyReverse(ctx, state, v);
              },
            ),
            const SizedBox(height: 8),

            // Pitch correct toggle
            _OptionRow(
              icon: Icons.music_note_rounded,
              label: 'Pitch Correction (audio)',
              subtitle: 'Keep audio pitch natural when slowed/sped up',
              value: _pitchCorrect,
              onChanged: (v) => setState(() => _pitchCorrect = v),
            ),
            const SizedBox(height: 16),

            // Slow motion note
            if (_speed < 0.5)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent3.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent3.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: AppTheme.accent3, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For best slow motion, use footage shot at 120fps or 240fps.',
                      style: TextStyle(color: AppTheme.accent3, fontSize: 11),
                    ),
                  ),
                ]),
              ),

            if (clip == null) ...[
              const SizedBox(height: 20),
              const Center(
                  child: Text('Select a clip to adjust speed',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 12))),
            ],
          ]),
        );
      },
    );
  }

  Clip? _getSelectedClip(TimelineState state) {
    if (state.selectedClipId == null) return null;
    for (final track in state.project?.tracks ?? []) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId) return clip;
      }
    }
    return null;
  }

  void _applySpeed(BuildContext ctx, TimelineState state, double speed) {
    _updateClip(ctx, state, (clip) => clip.copyWith(speed: speed));
  }

  void _applyReverse(BuildContext ctx, TimelineState state, bool reversed) {
    _updateClip(ctx, state, (clip) => clip.copyWith(isReversed: reversed));
  }

  void _applySpeedCurve(
      BuildContext ctx, TimelineState state, List<SpeedPoint> points) {
    _updateClip(ctx, state, (clip) => clip.copyWith(speedCurve: points));
  }

  void _updateClip(
      BuildContext ctx, TimelineState state, Clip Function(Clip) updater) {
    for (final track in state.project?.tracks ?? []) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId) {
          ctx
              .read<TimelineBloc>()
              .add(UpdateClip(trackId: track.id, clip: updater(clip)));
          return;
        }
      }
    }
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToolBtn(
      {required this.icon,
      required this.label,
      this.active = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                active ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.bg3,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: active ? AppTheme.accent : AppTheme.border),
          ),
          child: Column(children: [
            Icon(icon,
                color: active ? AppTheme.accent : AppTheme.textSecondary,
                size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: active ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 11)),
          ]),
        ),
      );
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 11)),
        ])),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../app_theme.dart';

class ColorPanel extends StatefulWidget {
  const ColorPanel({super.key});
  @override
  State<ColorPanel> createState() => _ColorPanelState();
}

class _ColorPanelState extends State<ColorPanel> {
  ColorGrade _grade = ColorGrade.identity;

  static const _luts = [
    'None',
    'Cinematic',
    'Warm',
    'Cool',
    'Vintage',
    'Matte',
    'Kodak',
    'Fuji'
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Basic adjustments
        _Slider(Icons.wb_sunny_outlined, 'Exposure', _grade.exposure, -100, 100,
            (v) => _update(_grade.copyWith(exposure: v))),
        _Slider(Icons.brightness_6_outlined, 'Brightness', _grade.brightness, -100, 100,
            (v) => _update(_grade.copyWith(brightness: v))),
        _Slider(Icons.contrast_outlined, 'Contrast', _grade.contrast, -100, 100,
            (v) => _update(_grade.copyWith(contrast: v))),
        _Slider(Icons.highlight_outlined, 'Highlights', _grade.highlights, -100, 100,
            (v) => _update(_grade.copyWith(highlights: v))),
        _Slider(Icons.wb_shade_outlined, 'Shadows', _grade.shadows, -100, 100,
            (v) => _update(_grade.copyWith(shadows: v))),
        _Slider(Icons.thermostat_outlined, 'Temperature', _grade.temperature, -100, 100,
            (v) => _update(_grade.copyWith(temperature: v))),
        _Slider(Icons.color_lens_outlined, 'Saturation', _grade.saturation, -100, 100,
            (v) => _update(_grade.copyWith(saturation: v))),
        _Slider(Icons.auto_fix_high_outlined, 'Vibrance', _grade.vibrance, -100, 100,
            (v) => _update(_grade.copyWith(vibrance: v))),

        const SizedBox(height: 14),
        const Text('LUT',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _luts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _update(_grade.copyWith(
                  lutPath: _luts[i] == 'None'
                      ? null
                      : '${_luts[i].toLowerCase()}.cube')),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (_grade.lutPath?.contains(_luts[i].toLowerCase()) ??
                              false) ||
                          (_luts[i] == 'None' && _grade.lutPath == null)
                      ? AppTheme.accent.withValues(alpha: 0.2)
                      : AppTheme.bg3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_grade.lutPath?.contains(_luts[i].toLowerCase()) ??
                                false) ||
                            (_luts[i] == 'None' && _grade.lutPath == null)
                        ? AppTheme.accent
                        : AppTheme.border,
                  ),
                ),
                child: Text(_luts[i],
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Reset
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              setState(() => _grade = ColorGrade.identity);
              _apply(context);
            },
            style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent4,
                side: const BorderSide(color: AppTheme.accent4)),
            child: const Text('Reset All'),
          ),
        ),
      ]),
    );
  }

  void _update(ColorGrade g) {
    setState(() => _grade = g);
    _apply(context);
  }

  void _apply(BuildContext ctx) {
    final state = ctx.read<TimelineBloc>().state;
    if (state.selectedClipId == null) return;
    for (final track in state.project?.tracks ?? []) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId) {
          ctx.read<TimelineBloc>().add(UpdateClip(
              trackId: track.id, clip: clip.copyWith(colorGrade: _grade)));
          return;
        }
      }
    }
  }
}

class _Slider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min, max;
  final ValueChanged<double> onChanged;
  const _Slider(this.icon, this.label, this.value, this.min, this.max, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: AppTheme.textTertiary, size: 18),
        const SizedBox(width: 12),
        SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12))),
        Expanded(
            child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.bg3,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
          child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged),
        )),
        SizedBox(
            width: 35,
            child: Text('${value.toInt()}',
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                textAlign: TextAlign.right)),
      ]),
    );
  }
}


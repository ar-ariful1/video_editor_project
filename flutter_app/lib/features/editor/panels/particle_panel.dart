import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/advanced_features.dart';
import '../../../core/models/video_project.dart';
import '../../../app_theme.dart';

class ParticlePanel extends StatelessWidget {
  const ParticlePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (context, state) {
        final selectedClip = _getSelectedClip(state);
        if (selectedClip == null) {
          return const Center(
            child: Text(
              'Select a clip to add particles',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          );
        }

        return Column(
          children: [
            _buildParticleGrid(context, selectedClip),
            if (selectedClip.particleEffect != null)
              _buildAdjustments(context, selectedClip),
          ],
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

  Widget _buildParticleGrid(BuildContext context, Clip clip) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: ParticleType.values.map((type) {
          final isSelected = clip.particleEffect?.type == type;
          return Padding(
            padding: const EdgeInsets.right(12),
            child: GestureDetector(
              onTap: () => _toggleParticle(context, clip, type),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withOpacity(0.2) : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.border,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _getIconForType(type),
                      color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.name.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdjustments(BuildContext context, Clip clip) {
    final effect = clip.particleEffect!;
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSlider(
            context,
            'Count',
            effect.particleCount.toDouble(),
            10,
            500,
            (v) => _updateEffect(context, clip, effect.copyWith(particleCount: v.toInt())),
          ),
          _buildSlider(
            context,
            'Speed',
            effect.speed,
            0.1,
            5.0,
            (v) => _updateEffect(context, clip, effect.copyWith(speed: v)),
          ),
          _buildSlider(
            context,
            'Size',
            effect.size,
            0.1,
            10.0,
            (v) => _updateEffect(context, clip, effect.copyWith(size: v)),
          ),
          _buildSlider(
            context,
            'Opacity',
            effect.opacity,
            0.0,
            1.0,
            (v) => _updateEffect(context, clip, effect.copyWith(opacity: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: AppTheme.sliderTheme(context),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(ParticleType type) {
    switch (type) {
      case ParticleType.fire: return Icons.local_fire_department_rounded;
      case ParticleType.snow: return Icons.ac_unit_rounded;
      case ParticleType.rain: return Icons.umbrella_rounded;
      case ParticleType.spark: return Icons.auto_awesome_rounded;
      case ParticleType.smoke: return Icons.cloud_rounded;
      case ParticleType.bubble: return Icons.blur_on_rounded;
      case ParticleType.confetti: return Icons.celebration_rounded;
    }
  }

  void _toggleParticle(BuildContext context, Clip clip, ParticleType type) {
    final currentEffect = clip.particleEffect;
    ParticleEffect? newEffect;

    if (currentEffect?.type == type) {
      newEffect = null; // Toggle off
    } else {
      newEffect = ParticleEffect.create(type: type);
    }

    final trackId = context.read<TimelineBloc>().state.project!.tracks
        .firstWhere((t) => t.clips.any((c) => c.id == clip.id))
        .id;

    context.read<TimelineBloc>().add(UpdateClip(
      trackId: trackId,
      clip: clip.copyWith(particleEffect: newEffect),
    ));
  }

  void _updateEffect(BuildContext context, Clip clip, ParticleEffect effect) {
    final trackId = context.read<TimelineBloc>().state.project!.tracks
        .firstWhere((t) => t.clips.any((c) => c.id == clip.id))
        .id;

    context.read<TimelineBloc>().add(UpdateClip(
      trackId: trackId,
      clip: clip.copyWith(particleEffect: effect),
    ));
  }
}

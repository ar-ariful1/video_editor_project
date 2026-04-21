import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart' as model;
import '../../../core/models/video_project.dart' show Effect;
import '../../../app_theme.dart';

class EffectsPanel extends StatefulWidget {
  const EffectsPanel({super.key});
  @override
  State<EffectsPanel> createState() => _EffectsPanelState();
}

class _EffectsPanelState extends State<EffectsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static const _effects = [
    ('glitch', Icons.vignette_rounded, 'Glitch', 'RGB shift distortion'),
    ('vhs', Icons.videocam_off_rounded, 'VHS Retro', 'Old tape look'),
    ('blur', Icons.blur_on_rounded, 'Blur', 'Gaussian blur'),
    ('grain', Icons.grain_rounded, 'Film Grain', 'Vintage noise'),
    ('vignette', Icons.filter_center_focus_rounded, 'Vignette', 'Edge darkening'),
    ('chromatic', Icons.color_lens_rounded, 'Chromatic', 'Color aberration'),
    ('sharpen', Icons.shutter_speed_rounded, 'Sharpen', 'Edge enhancement'),
    ('pixelate', Icons.grid_view_rounded, 'Pixelate', '8-bit look'),
    ('halftone', Icons.texture_rounded, 'Halftone', 'Dot pattern'),
    ('fisheye', Icons.camera_rounded, 'Fisheye', 'Wide angle lens'),
    ('shake', Icons.vibration_rounded, 'Shake', 'Camera shake'),
    ('rain', Icons.water_drop_rounded, 'Rain', 'Rain overlay'),
  ];

  static const _transitions = [
    ('fade', Icons.brightness_6_rounded, 'Fade', 'Cross dissolve'),
    ('slide', Icons.keyboard_double_arrow_right_rounded, 'Slide', 'Push direction'),
    ('zoom', Icons.zoom_in_rounded, 'Zoom', 'Scale transition'),
    ('wipe', Icons.view_sidebar_rounded, 'Wipe', 'Wipe effect'),
    ('spin', Icons.autorenew_rounded, 'Spin', '3D rotation'),
    ('cube', Icons.view_in_ar_rounded, 'Cube', '3D cube flip'),
    ('dip_black', Icons.exposure_minus_1_rounded, 'Dip Black', 'Fade to black'),
    ('flash', Icons.flash_on_rounded, 'Flash', 'White flash'),
    ('glitch_t', Icons.monitor_heart_rounded, 'Glitch', 'Glitch smear'),
    ('morph', Icons.waves_rounded, 'Morph', 'Liquid morph'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tabs,
        tabs: const [Tab(text: 'Effects'), Tab(text: 'Transitions')],
        labelColor: AppTheme.accent,
        unselectedLabelColor: AppTheme.textTertiary,
        indicatorColor: AppTheme.accent,
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _buildEffectGrid(context),
          _buildTransitionGrid(context),
        ]),
      ),
    ]);
  }

  Widget _buildEffectGrid(BuildContext ctx) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: _effects.length,
      itemBuilder: (_, i) {
        final (type, icon, name, desc) = _effects[i];
        return GestureDetector(
          onTap: () => _applyEffect(ctx, type),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: AppTheme.textPrimary, size: 24),
              const SizedBox(height: 4),
              Text(name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(desc,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 9),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildTransitionGrid(BuildContext ctx) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: _transitions.length,
      itemBuilder: (_, i) {
        final (type, icon, name, desc) = _transitions[i];
        return GestureDetector(
          onTap: () => _applyTransition(ctx, type),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: AppTheme.textPrimary, size: 24),
              const SizedBox(height: 4),
              Text(name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(desc,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 9),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      },
    );
  }

  void _applyEffect(BuildContext ctx, String type) {
    final state = ctx.read<TimelineBloc>().state;
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Select a clip first')),
      );
      return;
    }
    // Find clip and update with new effect
    for (final track in state.project?.tracks ?? []) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId) {
          final effect = Effect.create(type: type);
          final updated = clip.copyWith(effects: [...clip.effects, effect]);
          ctx
              .read<TimelineBloc>()
              .add(UpdateClip(trackId: track.id, clip: updated));
          return;
        }
      }
    }
  }

  void _applyTransition(BuildContext ctx, String type) {
    final state = ctx.read<TimelineBloc>().state;
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text('Select a clip first')));
      return;
    }
    final transition = model.Transition(type: type, duration: 0.5);
    for (final track in state.project?.tracks ?? []) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId) {
          final updated = clip.copyWith(transitionOut: transition);
          ctx
              .read<TimelineBloc>()
              .add(UpdateClip(trackId: track.id, clip: updated));
          return;
        }
      }
    }
  }
}

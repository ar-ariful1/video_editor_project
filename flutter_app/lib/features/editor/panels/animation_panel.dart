// lib/features/editor/panels/animation_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

class AnimationPanel extends StatefulWidget {
  const AnimationPanel({super.key});
  @override
  State<AnimationPanel> createState() => _AnimationPanelState();
}

class _AnimationPanelState extends State<AnimationPanel> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  double _duration = 0.5;

  static const _inAnims = [
    ('fade_in', 'Fade In'),
    ('zoom_in', 'Zoom In'),
    ('slide_right', 'Slide Right'),
    ('slide_up', 'Slide Up'),
    ('spin', 'Spin In'),
  ];

  static const _outAnims = [
    ('fade_out', 'Fade Out'),
    ('zoom_out', 'Zoom Out'),
    ('slide_left', 'Slide Left'),
    ('slide_down', 'Slide Down'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  void _applyAnimation(String type, String animId) {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) return;

    final animation = KeyframeAnimation(
      id: animId,
      name: animId,
      keyframes: const [],
      duration: _duration,
    );

    for (final track in state.project?.tracks ?? []) {
      if (track.id == state.selectedTrackId) {
        for (final clip in track.clips) {
          if (clip.id == state.selectedClipId) {
            // Update clip with new animation
            final updatedClip = clip.copyWith(animation: animation);
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
      TabBar(
        controller: _tabs,
        tabs: const [Tab(text: 'In'), Tab(text: 'Out'), Tab(text: 'Combo')],
        labelColor: AppTheme.accent,
        indicatorColor: AppTheme.accent,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Text('Duration', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Expanded(
            child: Slider(
              value: _duration,
              min: 0.1,
              max: 2.0,
              onChanged: (v) => setState(() => _duration = v),
            ),
          ),
          Text('${_duration.toStringAsFixed(1)}s', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        ]),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _AnimGrid(anims: _inAnims, onSelect: (id) => _applyAnimation('in', id)),
          _AnimGrid(anims: _outAnims, onSelect: (id) => _applyAnimation('out', id)),
          _AnimGrid(anims: _inAnims, onSelect: (id) => _applyAnimation('combo', id)),
        ]),
      ),
    ]);
  }
}

class _AnimGrid extends StatelessWidget {
  final List<(String, String)> anims;
  final Function(String) onSelect;
  const _AnimGrid({required this.anims, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: anims.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => onSelect(anims[i].$1),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bg3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_fix_high_rounded, color: AppTheme.accent, size: 20),
              const SizedBox(height: 4),
              Text(anims[i].$2, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

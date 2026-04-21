// lib/features/editor/panels/beauty_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../core/services/feature_gate_service.dart';
import '../../subscription/subscription_bloc.dart';

class BeautyPanel extends StatefulWidget {
  const BeautyPanel({super.key});
  @override
  State<BeautyPanel> createState() => _BeautyPanelState();
}

class _BeautyPanelState extends State<BeautyPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  double _smooth = 0, _whitening = 0, _sharpen = 0, _faceSlim = 0, _eyeEnlarge = 0;
  int _selectedAR = -1;

  static const _arFilters = [
    ('none', '⬜', 'None'),
    ('cat', '🐱', 'Cat'),
    ('dog', '🐶', 'Dog'),
    ('bunny', '🐰', 'Bunny'),
    ('crown', '👑', 'Crown'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  void _syncWithBloc() {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) return;

    final beautyEffect = Effect.create(type: 'beauty', params: {
      'smooth': _smooth,
      'whitening': _whitening,
      'sharpen': _sharpen,
      'faceSlim': _faceSlim,
      'eyeEnlarge': _eyeEnlarge,
      'arFilter': _selectedAR >= 0 ? _arFilters[_selectedAR].$1 : 'none',
    });

    for (final track in state.project?.tracks ?? []) {
      if (track.id == state.selectedTrackId) {
        for (final clip in track.clips) {
          if (clip.id == state.selectedClipId) {
            final otherEffects = clip.effects.where((e) => e.type != 'beauty').toList();
            bloc.add(UpdateClip(trackId: track.id, clip: clip.copyWith(effects: [...otherEffects, beautyEffect])));
            return;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionBloc>().state;
    final hasAccess = FeatureGateService.hasAccess(sub.plan, Feature.beautyFilter);

    return Column(children: [
      TabBar(
        controller: _tabs,
        tabs: const [Tab(text: 'Beauty'), Tab(text: 'AR Filters')],
        labelColor: AppTheme.accent,
        indicatorColor: AppTheme.accent,
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _BeautySlider('Smooth', _smooth, (v) { setState(() => _smooth = v); _syncWithBloc(); }),
              _BeautySlider('Whitening', _whitening, (v) { setState(() => _whitening = v); _syncWithBloc(); }),
              _BeautySlider('Sharpen', _sharpen, (v) { setState(() => _sharpen = v); _syncWithBloc(); }),
              _BeautySlider('Face Slim', _faceSlim, (v) { setState(() => _faceSlim = v); _syncWithBloc(); }),
              _BeautySlider('Eye Enlarge', _eyeEnlarge, (v) { setState(() => _eyeEnlarge = v); _syncWithBloc(); }),
            ]),
          ),
          GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: _arFilters.length,
            itemBuilder: (_, i) {
              final selected = _selectedAR == i;
              return GestureDetector(
                onTap: () { setState(() => _selectedAR = i); _syncWithBloc(); },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Center(child: Text(_arFilters[i].$2, style: const TextStyle(fontSize: 24))),
                ),
              );
            },
          ),
        ]),
      ),
    ]);
  }
}

class _BeautySlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _BeautySlider(this.label, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
      Expanded(child: Slider(value: value, min: 0, max: 100, onChanged: onChanged)),
      Text('${value.toInt()}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
    ]),
  );
}

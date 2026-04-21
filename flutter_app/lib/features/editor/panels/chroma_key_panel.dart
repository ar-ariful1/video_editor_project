// lib/features/editor/panels/chroma_key_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../core/services/feature_gate_service.dart';
import '../../subscription/subscription_bloc.dart';

class ChromaKeyPanel extends StatefulWidget {
  const ChromaKeyPanel({super.key});
  @override
  State<ChromaKeyPanel> createState() => _ChromaKeyPanelState();
}

class _ChromaKeyPanelState extends State<ChromaKeyPanel> {
  Color _keyColor = const Color(0xFF00B140); // green
  double _similarity = 0.3;
  double _smoothness = 0.1;
  double _spill = 0.1;
  bool _enabled = false;

  static const _presetColors = [
    (Color(0xFF00B140), 'Green'),
    (Color(0xFF0047AB), 'Blue'),
    (Color(0xFFFF0000), 'Red'),
    (Color(0xFFFFFFFF), 'White'),
    (Color(0xFF000000), 'Black'),
  ];

  void _syncWithBloc() {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) return;

    if (!_enabled) {
        // Remove chroma key effect if disabled
        for (final track in state.project?.tracks ?? []) {
          if (track.id == state.selectedTrackId) {
            for (final clip in track.clips) {
              if (clip.id == state.selectedClipId) {
                final otherEffects = clip.effects.where((e) => e.type != 'chroma_key').toList();
                bloc.add(UpdateClip(trackId: track.id, clip: clip.copyWith(effects: otherEffects)));
                return;
              }
            }
          }
        }
        return;
    }

    final effect = Effect.create(type: 'chroma_key', params: {
      'color': '#${_keyColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      'similarity': _similarity,
      'smoothness': _smoothness,
      'spill': _spill,
    });

    for (final track in state.project?.tracks ?? []) {
      if (track.id == state.selectedTrackId) {
        for (final clip in track.clips) {
          if (clip.id == state.selectedClipId) {
            final otherEffects = clip.effects.where((e) => e.type != 'chroma_key').toList();
            bloc.add(UpdateClip(trackId: track.id, clip: clip.copyWith(effects: [...otherEffects, effect])));
            return;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionBloc>().state;
    final hasAccess = FeatureGateService.hasAccess(sub.plan, Feature.chromaKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Text('✂️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Chroma Key',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text('Remove background by color',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
              ])),
          Switch(
            value: _enabled,
            onChanged: hasAccess
                ? (v) {
                    setState(() => _enabled = v);
                    _syncWithBloc();
                  }
                : (_) => FeatureGateService.checkAndGate(
                    context, Feature.chromaKey,
                    featureName: 'Chroma Key'),
          ),
        ]),
        const SizedBox(height: 20),

        if (!hasAccess)
          _UpgradeBanner(feature: Feature.chromaKey, name: 'Chroma Key'),

        AbsorbPointer(
          absorbing: !hasAccess || !_enabled,
          child: Opacity(
            opacity: (hasAccess && _enabled) ? 1.0 : 0.4,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Color picker presets
              const Text('Key Color',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: [
                ..._presetColors.map((c) => GestureDetector(
                      onTap: () {
                        setState(() => _keyColor = c.$1);
                        _syncWithBloc();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c.$1,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _keyColor.toARGB32() == c.$1.toARGB32()
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    )),
              ]),
              const SizedBox(height: 20),

              _CKSlider('Similarity', _similarity, 0, 1, (v) {
                setState(() => _similarity = v);
                _syncWithBloc();
              }),
              _CKSlider('Smoothness', _smoothness, 0, 1, (v) {
                setState(() => _smoothness = v);
                _syncWithBloc();
              }),
              _CKSlider('Spill Reduction', _spill, 0, 1, (v) {
                setState(() => _spill = v);
                _syncWithBloc();
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _CKSlider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _CKSlider(this.label, this.value, this.min, this.max, this.onChanged);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12))),
          Expanded(
              child: Slider(
                  value: value, min: min, max: max, onChanged: onChanged)),
          SizedBox(
              width: 40,
              child: Text('${(value * 100).toInt()}%',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                  textAlign: TextAlign.right)),
        ]),
      );
}

class _UpgradeBanner extends StatelessWidget {
  final Feature feature;
  final String name;
  const _UpgradeBanner({required this.feature, required this.name});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3))),
        child: Row(children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Text('$name requires Pro plan',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12))),
          TextButton(
              onPressed: () => FeatureGateService.checkAndGate(context, feature,
                  featureName: name),
              child: const Text('Upgrade',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))),
        ]),
      );
}

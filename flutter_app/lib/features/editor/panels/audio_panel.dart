import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

class AudioPanel extends StatefulWidget {
  final String? selectedClipId;
  const AudioPanel({super.key, this.selectedClipId});
  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel> {
  double _masterVolume = 1.0;
  bool _noiseReduction = false;
  double _eqBass = 0.0;
  double _eqMid = 0.0;
  double _eqTreble = 0.0;

  @override
  Widget build(BuildContext context) {
    final timelineState = context.watch<TimelineBloc>().state;
    if (timelineState.project == null) return const SizedBox.shrink();

    final project = timelineState.project!;
    Clip? selectedClip;
    Track? selectedTrack;

    if (widget.selectedClipId != null) {
      for (final track in project.tracks) {
        for (final clip in track.clips) {
          if (clip.id == widget.selectedClipId) {
            selectedClip = clip;
            selectedTrack = track;
            break;
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (selectedClip != null && selectedTrack != null) ...[
          Text('Clip: ${selectedClip.mediaPath?.split('/').last ?? 'Selected Clip'}',
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          const Text('Clip Volume',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          Row(children: [
            const Icon(Icons.volume_down, color: AppTheme.textTertiary, size: 18),
            Expanded(
                child: Slider(
                    value: selectedClip.volume,
                    onChanged: (v) {
                      context.read<TimelineBloc>().add(UpdateClip(
                        trackId: selectedTrack!.id,
                        clip: selectedClip!.copyWith(volume: v),
                      ));
                    })),
            const Icon(Icons.volume_up, color: AppTheme.textTertiary, size: 18),
          ]),

          _SwitchRow('Noise Reduction (Native)', selectedClip.noiseReduction,
              (v) {
                context.read<TimelineBloc>().add(UpdateClip(
                  trackId: selectedTrack!.id,
                  clip: selectedClip!.copyWith(noiseReduction: v),
                ));
              }),
          const Divider(height: 32, color: AppTheme.border),
        ],

        // Master Settings
        const Text('Project Audio',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.volume_down, color: AppTheme.textTertiary, size: 18),
          Expanded(
              child: Slider(
                  value: _masterVolume,
                  onChanged: (v) => setState(() => _masterVolume = v))),
          const Icon(Icons.volume_up, color: AppTheme.textTertiary, size: 18),
        ]),

        const SizedBox(height: 12),
        // Noise reduction
        _SwitchRow('Noise Reduction (RNNoise)', _noiseReduction,
            (v) => setState(() => _noiseReduction = v)),

        const SizedBox(height: 16),
        const Text('EQ (10-band)',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _EQBand('Bass', _eqBass, (v) => setState(() => _eqBass = v)),
          _EQBand('Mid', _eqMid, (v) => setState(() => _eqMid = v)),
          _EQBand('Treble', _eqTreble, (v) => setState(() => _eqTreble = v)),
        ]),

        const SizedBox(height: 16),
        const Text('Audio Effects',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Reverb',
              'Echo',
              'Compressor',
              'Pitch Up',
              'Pitch Down',
              'Voice Changer',
            ]
                .map((e) => ActionChip(
                      label: Text(e,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      backgroundColor: AppTheme.bg3,
                      side: const BorderSide(color: AppTheme.border),
                      onPressed: () {},
                    ))
                .toList()),
      ]),
    );
  }
}

class _AudioSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AudioSourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: AppTheme.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Icon(icon, color: AppTheme.textPrimary, size: 20),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ]),
        ),
      );
}

class _EQBand extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _EQBand(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          SizedBox(
            height: 80,
            child: RotatedBox(
              quarterTurns: 3,
              child:
              Slider(
                  value: volume,
                   min: 0.0,
                   max: 2.0,
                   onChanged: (newVol) {
                   setState(() => volume = newVol);
                    // Send to native engine
                    NativeEngineService().setVolume(widget.clipId, newVol);
                },
                 )
            ),
          ),
          Text('${value.toInt() > 0 ? '+' : ''}${value.toInt()}dB',
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ]),
      );
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13))),
        Switch(value: value, onChanged: onChanged),
      ]);
}

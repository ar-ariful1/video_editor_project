// lib/features/editor/widgets/audio_controls_widget.dart
// Volume slider + Fade in/out — shown on selected audio clip
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

class AudioControlsWidget extends StatefulWidget {
  final Clip clip;
  final String trackId;
  const AudioControlsWidget(
      {super.key, required this.clip, required this.trackId});
  @override
  State<AudioControlsWidget> createState() => _AudioControlsWidgetState();
}

class _AudioControlsWidgetState extends State<AudioControlsWidget> {
  late double _volume;
  late double _fadeIn;
  late double _fadeOut;

  @override
  void initState() {
    super.initState();
    _volume = widget.clip.volume;
    _fadeIn = widget.clip.fadeIn;
    _fadeOut = widget.clip.fadeOut;
  }

  void _update() {
    final updated = widget.clip
        .copyWith(volume: _volume, fadeIn: _fadeIn, fadeOut: _fadeOut);
    context
        .read<TimelineBloc>()
        .add(UpdateClip(trackId: widget.trackId, clip: updated));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Audio Controls',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        // Volume
        Row(children: [
          const Icon(Icons.volume_down_rounded,
              color: AppTheme.textTertiary, size: 18),
          Expanded(
              child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
            child: Slider(
              value: _volume,
              min: 0,
              max: 1,
              onChanged: (v) => setState(() => _volume = v),
              onChangeEnd: (_) => _update(),
            ),
          )),
          const Icon(Icons.volume_up_rounded,
              color: AppTheme.textTertiary, size: 18),
          const SizedBox(width: 6),
          Text('${(_volume * 100).toInt()}%',
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        ]),

        const SizedBox(height: 10),
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 10),

        // Fade in
        Row(children: [
          const SizedBox(width: 4),
          const Text('Fade In',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Expanded(
              child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
            child: Slider(
              value: _fadeIn,
              min: 0,
              max: 3,
              onChanged: (v) => setState(() => _fadeIn = v),
              onChangeEnd: (_) => _update(),
            ),
          )),
          SizedBox(
              width: 42,
              child: Text(
                  _fadeIn > 0 ? '${_fadeIn.toStringAsFixed(1)}s' : 'Off',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                  textAlign: TextAlign.right)),
        ]),

        // Fade out
        Row(children: [
          const SizedBox(width: 4),
          const Text('Fade Out',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Expanded(
              child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
            child: Slider(
              value: _fadeOut,
              min: 0,
              max: 3,
              onChanged: (v) => setState(() => _fadeOut = v),
              onChangeEnd: (_) => _update(),
            ),
          )),
          SizedBox(
              width: 42,
              child: Text(
                  _fadeOut > 0 ? '${_fadeOut.toStringAsFixed(1)}s' : 'Off',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                  textAlign: TextAlign.right)),
        ]),

        // Visual fade preview
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: CustomPaint(
              painter: _FadePainter(
                  fadeIn: _fadeIn, fadeOut: _fadeOut, volume: _volume)),
        ),
      ]),
    );
  }
}

class _FadePainter extends CustomPainter {
  final double fadeIn, fadeOut, volume;
  const _FadePainter(
      {required this.fadeIn, required this.fadeOut, required this.volume});

  @override
  void paint(Canvas canvas, Size size) {
    final total = 10.0; // assume 10s clip for preview
    final fadeInPx = (fadeIn / total) * size.width;
    final fadeOutPx = (fadeOut / total) * size.width;
    final midY = size.height / 2;
    final ampY = midY * volume;

    final path = Path()..moveTo(0, midY);
    if (fadeIn > 0)
      path.lineTo(fadeInPx, midY - ampY);
    else
      path.lineTo(0, midY - ampY);

    if (fadeOut > 0) {
      path.lineTo(size.width - fadeOutPx, midY - ampY);
      path.lineTo(size.width, midY);
    } else {
      path.lineTo(size.width, midY - ampY);
      path.lineTo(size.width, midY);
    }
    path.lineTo(0, midY);
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.accent2.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.accent2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_FadePainter old) =>
      old.fadeIn != fadeIn || old.fadeOut != fadeOut || old.volume != volume;
}

// ── Quick volume control (compact — in toolbar area) ──────────────────────────
class QuickVolumeControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  const QuickVolumeControl(
      {super.key, required this.volume, required this.onChanged});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: () => onChanged(volume > 0 ? 0 : 1),
          child: Icon(
              volume == 0
                  ? Icons.volume_off_rounded
                  : volume < 0.5
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
              color: AppTheme.textSecondary,
              size: 18),
        ),
        SizedBox(
            width: 80,
            child: Slider(
              value: volume,
              min: 0,
              max: 1,
              onChanged: onChanged,
              activeColor: AppTheme.accent2,
            )),
        Text('${(volume * 100).toInt()}%',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
      ]);
}


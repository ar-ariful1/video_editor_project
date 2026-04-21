// lib/features/editor/panels/voiceover_panel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../core/utils/utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum RecordingState { idle, countdown, recording, paused, done }

class VoiceoverPanel extends StatefulWidget {
  const VoiceoverPanel({super.key});
  @override
  State<VoiceoverPanel> createState() => _VoiceoverPanelState();
}

class _VoiceoverPanelState extends State<VoiceoverPanel>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle;
  int _countdown = 3;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Timer? _countdownTimer;
  String? _recordingPath;
  double _amplitude = 0;

  // Settings
  bool _noiseReduction = true;
  double _micGain = 1.0;
  bool _monitorInput = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<bool> _checkPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> _startCountdown() async {
    if (!await _checkPermission()) {
      if (mounted) showError(context, 'Microphone permission required');
      return;
    }
    setState(() {
      _state = RecordingState.countdown;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _startRecording();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voiceover_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        noiseSuppress: _noiseReduction,
      ),
      path: _recordingPath!,
    );

    setState(() {
      _state = RecordingState.recording;
      _elapsed = Duration.zero;
    });
    _pulseCtrl.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!mounted) return;
      final amp = await _recorder.getAmplitude();
      setState(() {
        _elapsed += const Duration(milliseconds: 100);
        _amplitude = ((amp.current + 60) / 60).clamp(0, 1);
      });
    });
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    _timer?.cancel();
    _pulseCtrl.stop();
    setState(() => _state = RecordingState.paused);
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    _pulseCtrl.repeat(reverse: true);
    setState(() => _state = RecordingState.recording);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!mounted) return;
      final amp = await _recorder.getAmplitude();
      setState(() {
        _elapsed += const Duration(milliseconds: 100);
        _amplitude = ((amp.current + 60) / 60).clamp(0, 1);
      });
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    _timer?.cancel();
    _pulseCtrl.stop();
    setState(() {
      _state = RecordingState.done;
      _recordingPath = path;
    });
  }

  void _discardRecording() {
    setState(() {
      _state = RecordingState.idle;
      _elapsed = Duration.zero;
      _recordingPath = null;
    });
  }

  void _addToTimeline(BuildContext ctx) {
    if (_recordingPath == null) return;
    final state = ctx.read<TimelineBloc>().state;
    final startTime = state.currentTime;
    final durationSec = _elapsed.inMilliseconds / 1000.0;

    final clip = Clip(
      id: _uuid.v4(),
      startTime: startTime,
      endTime: startTime + durationSec,
      mediaPath: _recordingPath,
      mediaType: 'audio',
      volume: _micGain,
    );

    // Find or create voiceover track
    final voiceTrack = state.project?.tracks.firstWhere(
      (t) => t.type == TrackType.audio && t.name.contains('Voice'),
      orElse: () =>
          Track.create(name: 'Voiceover', type: TrackType.audio, zIndex: 3),
    );

    if (voiceTrack != null) {
      ctx.read<TimelineBloc>().add(AddClip(trackId: voiceTrack.id, clip: clip));
      showSuccess(ctx,
          '✅ Voiceover added to timeline (${formatDuration(durationSec)})');
      _discardRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (ctx, state) {
        return Column(children: [
          // Visualizer
          Container(
            height: 100,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppTheme.bg3,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border)),
            child: _state == RecordingState.idle ||
                    _state == RecordingState.done
                ? const Center(
                    child: Icon(Icons.mic_none_rounded,
                        color: AppTheme.textTertiary, size: 40))
                : _state == RecordingState.countdown
                    ? Center(
                        child: Text('$_countdown',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 52,
                                fontWeight: FontWeight.w800)))
                    : AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Center(
                          child: Container(
                            width: 60 + _amplitude * 40,
                            height: 60 + _amplitude * 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accent4
                                  .withValues(alpha: 0.2 + _amplitude * 0.4),
                              border:
                                  Border.all(color: AppTheme.accent4, width: 2),
                            ),
                            child: const Center(
                                child: Icon(Icons.mic_rounded,
                                    color: AppTheme.accent4, size: 28)),
                          ),
                        ),
                      ),
          ),

          // Timer
          if (_state == RecordingState.recording ||
              _state == RecordingState.paused ||
              _state == RecordingState.done)
            Text(
              '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}.${((_elapsed.inMilliseconds % 1000) ~/ 100)}',
              style: TextStyle(
                color: _state == RecordingState.recording
                    ? AppTheme.accent4
                    : AppTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),

          const SizedBox(height: 16),

          // Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildControls(ctx),
          ),

          const SizedBox(height: 20),

          // Settings (only in idle)
          if (_state == RecordingState.idle) ...[
            const Divider(color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settings',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _SettingRow('Noise Reduction', _noiseReduction,
                        (v) => setState(() => _noiseReduction = v)),
                    _SettingRow('Monitor Input', _monitorInput,
                        (v) => setState(() => _monitorInput = v)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const SizedBox(width: 4),
                      const Text('Mic Gain',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13)),
                      Expanded(
                          child: Slider(
                              value: _micGain,
                              min: 0.5,
                              max: 2.0,
                              onChanged: (v) => setState(() => _micGain = v))),
                      Text('${(_micGain * 100).toInt()}%',
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 11)),
                    ]),
                  ]),
            ),
          ],
        ]);
      },
    );
  }

  Widget _buildControls(BuildContext ctx) {
    switch (_state) {
      case RecordingState.idle:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _startCountdown,
            icon: const Icon(Icons.mic_rounded, size: 22),
            label: const Text('Start Recording',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
          ),
        );

      case RecordingState.countdown:
        return const Center(
            child: Text('Get ready…',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)));

      case RecordingState.recording:
        return Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            onPressed: _pauseRecording,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )),
        ]);

      case RecordingState.paused:
        return Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            onPressed: _resumeRecording,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Resume'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.green,
                side: const BorderSide(color: AppTheme.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )),
        ]);

      case RecordingState.done:
        return Column(children: [
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
              onPressed: _discardRecording,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Discard'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent4,
                  side: const BorderSide(color: AppTheme.accent4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton.icon(
              onPressed: () => _addToTimeline(ctx),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add to Timeline',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _startCountdown,
            icon: const Icon(Icons.fiber_manual_record_rounded,
                color: AppTheme.accent4, size: 14),
            label: const Text('Record Again'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ]);
    }
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingRow(this.label, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13))),
        Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.accent),
      ]);
}


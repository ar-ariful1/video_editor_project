// lib/features/editor/panels/tts_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

class TTSPanel extends StatefulWidget {
  const TTSPanel({super.key});
  @override
  State<TTSPanel> createState() => _TTSPanelState();
}

class _TTSPanelState extends State<TTSPanel> {
  final _textCtrl = TextEditingController();
  String _selectedVoice = 'nova';
  String _selectedLang = 'en';
  double _speed = 1.0;
  double _pitch = 1.0;
  bool _generating = false;

  static const _voices = [
    ('nova', '👩', 'Nova', 'Female, warm'),
    ('alloy', '🧑', 'Alloy', 'Neutral, clear'),
    ('echo', '👨', 'Echo', 'Male, deep'),
    ('fable', '👩', 'Fable', 'Female, soft'),
    ('onyx', '👨', 'Onyx', 'Male, authoritative'),
    ('shimmer', '👩', 'Shimmer', 'Female, energetic'),
  ];

  static const _languages = [
    ('en', '🇺🇸', 'English'),
    ('bn', '🇧🇩', 'Bengali'),
    ('es', '🇪🇸', 'Spanish'),
    ('fr', '🇫🇷', 'French'),
    ('de', '🇩🇪', 'German'),
    ('hi', '🇮🇳', 'Hindi'),
    ('ar', '🇸🇦', 'Arabic'),
    ('zh', '🇨🇳', 'Chinese'),
    ('ja', '🇯🇵', 'Japanese'),
    ('pt', '🇧🇷', 'Portuguese'),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate(BuildContext ctx) async {
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() => _generating = true);
    try {
      // Call TTS API (OpenAI TTS or ElevenLabs)
      // final audioPath = await TTSService().generate(text: _textCtrl.text, voice: _selectedVoice, speed: _speed);
      await Future.delayed(const Duration(seconds: 2)); // simulate

      // Add to timeline as audio clip
      final state = ctx.read<TimelineBloc>().state;
      final startTime = state.currentTime;
      // Estimate duration: ~150 words/min / speed
      final wordCount = _textCtrl.text.split(' ').length;
      final durationSec = (wordCount / 150) * 60 / _speed;

      final audioClip = Clip.create(
        startTime: startTime,
        endTime: startTime + durationSec,
        mediaType: 'audio',
        // mediaPath: audioPath,
      );

      final voiceTrack = state.project?.tracks.firstWhere(
        (t) => t.type == TrackType.audio && t.name.contains('Voice'),
        orElse: () =>
            Track.create(name: 'Voiceover', type: TrackType.audio, zIndex: 2),
      );
      if (voiceTrack != null) {
        ctx
            .read<TimelineBloc>()
            .add(AddClip(trackId: voiceTrack.id, clip: audioClip));
      }
      if (mounted)
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
            content: Text('✅ Voiceover added to timeline'),
            backgroundColor: AppTheme.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: AppTheme.accent4));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Text input
        const Text('Text',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _textCtrl,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter text to convert to speech…',
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            counterStyle: const TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.bg3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.accent)),
          ),
        ),
        const SizedBox(height: 14),

        // Language
        const Text('Language',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _languages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final lang = _languages[i];
              final sel = _selectedLang == lang.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedLang = lang.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Row(children: [
                    Text(lang.$2, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(lang.$3,
                        style: TextStyle(
                            color:
                                sel ? AppTheme.accent : AppTheme.textTertiary,
                            fontSize: 12)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Voice
        const Text('Voice',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(
            _voices.length ~/ 2,
            (row) => Row(
                  children: [0, 1].map((col) {
                    final i = row * 2 + col;
                    if (i >= _voices.length)
                      return const Expanded(child: SizedBox());
                    final v = _voices[i];
                    final sel = _selectedVoice == v.$1;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedVoice = v.$1),
                        child: Container(
                          margin: EdgeInsets.only(
                              right: col == 0 ? 6 : 0, bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.accent.withValues(alpha: 0.15)
                                : AppTheme.bg3,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: sel ? AppTheme.accent : AppTheme.border),
                          ),
                          child: Row(children: [
                            Text(v.$2, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(v.$3,
                                      style: TextStyle(
                                          color: sel
                                              ? AppTheme.accent
                                              : AppTheme.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  Text(v.$4,
                                      style: const TextStyle(
                                          color: AppTheme.textTertiary,
                                          fontSize: 10)),
                                ])),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                )),
        const SizedBox(height: 14),

        // Speed / Pitch
        _Slider2('Speed', _speed, 0.5, 2.0, '${_speed.toStringAsFixed(1)}x',
            (v) => setState(() => _speed = v)),
        const SizedBox(height: 6),
        _Slider2('Pitch', _pitch, 0.5, 2.0, '${_pitch.toStringAsFixed(1)}x',
            (v) => setState(() => _pitch = v)),
        const SizedBox(height: 16),

        // Generate button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _generating ? null : () => _generate(context),
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.record_voice_over_rounded),
            label: Text(_generating ? 'Generating…' : 'Generate Voiceover'),
          ),
        ),
      ]),
    );
  }
}

class _Slider2 extends StatelessWidget {
  final String label, valueLabel;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _Slider2(this.label, this.value, this.min, this.max, this.valueLabel,
      this.onChanged);

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 50,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12))),
        Expanded(
            child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        )),
        SizedBox(
            width: 36,
            child: Text(valueLabel,
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                textAlign: TextAlign.right)),
      ]);
}


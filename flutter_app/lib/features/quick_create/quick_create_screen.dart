// lib/features/quick_create/quick_create_screen.dart
import 'dart:typed_data' as typed;
import 'package:flutter/material.dart' hide Clip;
import 'package:flutter/material.dart' as material show Clip;
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';

import '../../app_theme.dart';
import '../media/media_picker_screen.dart';
import '../music/music_library_screen.dart';
import '../../core/models/video_project.dart' as model;
import '../../core/models/video_project.dart' show VideoProject, Track, TrackType, Resolution, Clip;
import '../../core/utils/utils.dart';

typedef CanvasClip = material.Clip;
const _uuid = Uuid();

class MusicTrack {
  final String title;
  final double durationSeconds;
  MusicTrack({required this.title, required this.durationSeconds});
}

class QuickCreateScreen extends StatefulWidget {
  const QuickCreateScreen({super.key});
  @override
  State<QuickCreateScreen> createState() => _QuickCreateScreenState();
}

class _QuickCreateScreenState extends State<QuickCreateScreen> {
  final List<AssetEntity> _selectedMedia = [];
  MusicTrack? _selectedMusic;
  String _selectedRatio = '9:16';
  String _selectedStyle = 'dynamic';
  bool _autoSync = true;
  bool _generating = false;

  static const _ratios = ['9:16', '16:9', '1:1', '4:5'];
  static const _styles = [
    ('dynamic', '⚡', 'Dynamic'),
    ('cinematic', '🎬', 'Cinematic'),
    ('smooth', '🌊', 'Smooth'),
    ('slideshow', '📸', 'Slideshow'),
    ('lyric', '🎵', 'Lyric video'),
  ];

  Future<void> _pickMedia() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg2,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: MediaPickerScreen(
          allowMultiple: true,
          onSelected: (assets) => setState(() => _selectedMedia.addAll(assets)),
        ),
      ),
    );
  }

  Future<void> _pickMusic() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg2,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: MusicLibraryScreen(
            onSelected: (track) => setState(() => _selectedMusic = track as MusicTrack?)),
      ),
    );
  }

  Future<void> _generate() async {
    if (_selectedMedia.isEmpty) {
      showError(context, 'Add at least one photo or video');
      return;
    }
    setState(() => _generating = true);
    try {
      await Future.delayed(
          const Duration(seconds: 2)); // simulate AI arrangement
      final resolution = _ratioToResolution(_selectedRatio);
      final clips = <Clip>[];
      double t = 0;
      final clipDur = _selectedMusic != null
          ? (_selectedMusic!.durationSeconds / _selectedMedia.length)
          : 3.0;
      for (int i = 0; i < _selectedMedia.length; i++) {
        final file = await _selectedMedia[i].file;
        clips.add(Clip(
          id: _uuid.v4(),
          startTime: t,
          endTime: t + clipDur,
          mediaPath: file?.path,
          transitionOut: i < _selectedMedia.length - 1
              ? const model.Transition(type: 'fade', duration: 0.4)
              : null,
        ));
        t += clipDur;
      }
      final project = VideoProject(
        id: _uuid.v4(),
        name: 'Quick Create ${DateTime.now().day}/${DateTime.now().month}',
        duration: t,
        resolution: resolution,
        tracks: [
          Track(
              id: _uuid.v4(),
              name: 'Video',
              type: TrackType.video,
              zIndex: 1,
              clips: clips)
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed('/editor', arguments: {'project': project});
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        showError(context, 'Failed: $e');
      }
    }
  }

  Resolution _ratioToResolution(String ratio) {
    switch (ratio) {
      case '16:9':
        return const Resolution(width: 1920, height: 1080, frameRate: 30);
      case '1:1':
        return const Resolution(width: 1080, height: 1080, frameRate: 30);
      case '4:5':
        return const Resolution(width: 1080, height: 1350, frameRate: 30);
      default:
        return const Resolution(width: 1080, height: 1920, frameRate: 30);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
          backgroundColor: AppTheme.bg2,
          title: const Text('Quick Create'),
          leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Media grid
          _SectionTitle('Photos & Videos (${_selectedMedia.length})'),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.bg3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.accent, style: BorderStyle.solid)),
                  child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            color: AppTheme.accent, size: 24),
                        SizedBox(height: 4),
                        Text('Add',
                            style: TextStyle(
                                color: AppTheme.accent, fontSize: 10)),
                      ]),
                ),
              ),
              ..._selectedMedia.map((a) => FutureBuilder<typed.Uint8List?>(
                    future:
                        a.thumbnailDataWithSize(const ThumbnailSize(160, 160)),
                    builder: (_, snap) => Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      clipBehavior: CanvasClip.antiAlias,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10)),
                      child: snap.data != null
                          ? Image.memory(snap.data!, fit: BoxFit.cover)
                          : Container(color: AppTheme.bg3),
                    ),
                  )),
            ]),
          ),
          const SizedBox(height: 20),

          // Aspect ratio
          _SectionTitle('Format'),
          const SizedBox(height: 8),
          Row(
              children: _ratios.map((r) {
            final sel = _selectedRatio == r;
            return Expanded(
                child: GestureDetector(
              onTap: () => setState(() => _selectedRatio = r),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? AppTheme.accent : AppTheme.border),
                ),
                child: Text(r,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: sel ? AppTheme.accent : AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ));
          }).toList()),
          const SizedBox(height: 20),

          // Style
          _SectionTitle('Style'),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styles.map((s) {
                final sel = _selectedStyle == s.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStyle = s.$1),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(s.$2, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(s.$3,
                          style: TextStyle(
                              color: sel
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                              fontSize: 12)),
                    ]),
                  ),
                );
              }).toList()),
          const SizedBox(height: 20),

          // Music
          _SectionTitle('Music'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickMusic,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppTheme.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _selectedMusic != null
                          ? AppTheme.accent
                          : AppTheme.border)),
              child: Row(children: [
                Icon(
                    _selectedMusic != null
                        ? Icons.music_note_rounded
                        : Icons.add_rounded,
                    color: _selectedMusic != null
                        ? AppTheme.accent
                        : AppTheme.textTertiary,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_selectedMusic?.title ?? 'Choose music…',
                        style: TextStyle(
                            color: _selectedMusic != null
                                ? AppTheme.textPrimary
                                : AppTheme.textTertiary,
                            fontSize: 14))),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textTertiary, size: 16),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Text('Auto-sync to beat',
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13))),
            Switch(
                value: _autoSync,
                onChanged: (v) => setState(() => _autoSync = v)),
          ]),
          const SizedBox(height: 28),

          // Generate button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _generating ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _generating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Generating…',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ])
                  : const Text('🚀 Create Video',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700));
}

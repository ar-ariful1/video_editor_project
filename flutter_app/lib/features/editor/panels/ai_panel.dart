// lib/features/editor/panels/ai_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/models/video_project.dart';

import '../widgets/ai_mask_selector.dart';
import 'dart:io';

class AIPanel extends StatefulWidget {
  const AIPanel({super.key});
  @override
  State<AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends State<AIPanel> {
  bool _isProcessing = false;
  String _processStatus = '';
  double _progress = 0;

  Future<void> _generateAutoCaptions() async {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    final project = state.project;

    if (project == null) return;

    // Find the primary video track to extract audio from
    final videoTrack = project.tracks.firstWhere(
      (t) => t.type == TrackType.video,
      orElse: () => project.tracks.first,
    );

    if (videoTrack.clips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clips found to generate captions from.')),
      );
      return;
    }

    // Usually, we'd pick the first clip or merge audio. For this MVP, we pick the first clip.
    final firstClip = videoTrack.clips.first;
    if (firstClip.mediaPath == null) return;

    setState(() {
      _isProcessing = true;
      _processStatus = 'Generating Auto Captions...';
      _progress = 0;
    });

    try {
      final aiService = AIService();
      // Assume token is handled inside service or not needed for local
      final result = await aiService.transcribeVideo(
        firstClip.mediaPath!,
        onProgress: (p) => setState(() => _progress = p),
      );

      final layers = aiService.transcriptionToTextLayers(result);

      // Add a dedicated Captions track if it doesn't exist
      String targetTrackId = 'captions_track';
      final hasCaptionsTrack = project.tracks.any((t) => t.id == targetTrackId);

      if (!hasCaptionsTrack) {
        bloc.add(const AddTrack(type: TrackType.text, name: 'Captions'));
      }

      bloc.add(AddMultipleClips(trackId: targetTrackId, clips: layers));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Successfully generated ${layers.length} captions')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _removeBackground() async {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a clip first')),
      );
      return;
    }

    final track = state.project?.tracks
        .firstWhereOrNull((t) => t.id == state.selectedTrackId);
    final clip = track?.clips.firstWhereOrNull((c) => c.id == state.selectedClipId);

    if (clip == null || clip.mediaPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected clip not found or has no media.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = 'Removing Background...';
      _progress = 0;
    });

    try {
      final aiService = AIService();
      File result;
      if (clip.mediaType == 'video') {
        result = await aiService.removeBackgroundVideo(clip.mediaPath!,
            onProgress: (p) => setState(() => _progress = p));
      } else {
        result = await aiService.removeBackgroundImage(clip.mediaPath!);
      }

      bloc.add(ReplaceClip(
        trackId: state.selectedTrackId!,
        clipId: state.selectedClipId!,
        newMediaPath: result.path,
        isAdjustmentLayer: clip.isAdjustmentLayer,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Background removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startSmartTracking() async {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video clip to track')),
      );
      return;
    }

    final track = state.project?.tracks
        .firstWhereOrNull((t) => t.id == state.selectedTrackId);
    final clip = track?.clips.firstWhereOrNull((c) => c.id == state.selectedClipId);

    if (clip == null || clip.mediaPath == null || clip.mediaType != 'video') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected clip is not a valid video')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = 'AI Smart Tracking...';
      _progress = 0;
    });

    try {
      final aiService = AIService();
      final trackingResults = await aiService.trackObject(
        clip.mediaPath!,
        onProgress: (p) => setState(() => _progress = p),
      );

      final keyframes = aiService.trackingToKeyframes(trackingResults);

      bloc.add(AddKeyframes(
        trackId: state.selectedTrackId!,
        clipId: state.selectedClipId!,
        keyframes: keyframes,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Successfully tracked object with ${trackingResults.length} frames')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Tracking Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _enhanceResolution() async {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a clip to upscale')),
      );
      return;
    }

    final track = state.project?.tracks
        .firstWhereOrNull((t) => t.id == state.selectedTrackId);
    final clip = track?.clips.firstWhereOrNull((c) => c.id == state.selectedClipId);

    if (clip == null || clip.mediaPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected clip not found or has no media.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = 'AI 4K Upscaling (Starting Job)...';
      _progress = 0;
    });

    try {
      final aiService = AIService();

      if (clip.mediaType == 'image') {
        final result = await aiService.upscaleImage(clip.mediaPath!);
        bloc.add(ReplaceClip(
          trackId: state.selectedTrackId!,
          clipId: state.selectedClipId!,
          newMediaPath: result.path,
          isAdjustmentLayer: clip.isAdjustmentLayer,
        ));
      } else {
        final jobId = await aiService.startVideoUpscale(clip.mediaPath!);

        // Poll for completion
        bool completed = false;
        while (!completed) {
          await Future.delayed(const Duration(seconds: 3));
          final status = await aiService.getUpscaleStatus(jobId);

          if (mounted) {
            setState(() {
              _processStatus = 'AI 4K Upscaling...';
              _progress = status.progress;
            });
          }

          if (status.status == 'done') {
            final outPath = clip.mediaPath!.replaceAll(RegExp(r'\.\w+$'), '_4k.mp4');
            final result = await aiService.downloadUpscaledVideo(jobId, outPath);
            bloc.add(ReplaceClip(
              trackId: state.selectedTrackId!,
              clipId: state.selectedClipId!,
              newMediaPath: result.path,
              isAdjustmentLayer: clip.isAdjustmentLayer,
            ));
            completed = true;
          } else if (status.status == 'error') {
            throw Exception('Upscale job failed on server');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Resolution enhanced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upscale Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg2,
      child: Column(
        children: [
          if (_isProcessing)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(_processStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${(_progress * 100).toInt()}%',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppTheme.bg3,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AIButton(
                    title: 'Auto Captions',
                    subtitle: 'Generate subtitles using AI speech-to-text',
                    icon: Icons.closed_caption_rounded,
                    color: Colors.blueAccent,
                    onTap: _generateAutoCaptions,
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'Background Remover',
                    subtitle: 'Extract subjects with one tap',
                    icon: Icons.person_remove_rounded,
                    color: Colors.purpleAccent,
                    onTap: _removeBackground,
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'AI Smart Tracking',
                    subtitle: 'Track objects and attach text/effects',
                    icon: Icons.track_changes_rounded,
                    color: Colors.orangeAccent,
                    onTap: _startSmartTracking,
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'Enhance Resolution',
                    subtitle: 'Upscale video to 4K using AI',
                    icon: Icons.high_quality_rounded,
                    color: Colors.greenAccent,
                    onTap: _enhanceResolution,
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'AI Object Removal',
                    subtitle: 'Select objects to remove from the scene',
                    icon: Icons.auto_fix_high_rounded,
                    color: Colors.redAccent,
                    onTap: _startObjectRemoval,
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'Smart Cutout',
                    subtitle: 'Select objects to keep or remove',
                    icon: Icons.auto_fix_normal_rounded,
                    color: Colors.cyanAccent,
                    onTap: _startSmartCutout,
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'Auto-Beat Sync',
                    subtitle: 'Align cuts to music automatically',
                    icon: Icons.music_note_rounded,
                    color: Colors.pinkAccent,
                    onTap: _autoBeatSync,
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'AI Remix',
                    subtitle: 'Generate new styles from your video',
                    icon: Icons.auto_awesome_motion_rounded,
                    color: Colors.indigoAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AI Remix coming soon in the next update!')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _AIButton(
                    title: 'AI Expand',
                    subtitle: 'Generative fill for out-of-frame areas',
                    icon: Icons.aspect_ratio_rounded,
                    color: Colors.amberAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AI Expand coming soon!')),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startObjectRemoval() async {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a clip first')),
      );
      return;
    }

    final track = state.project?.tracks.firstWhereOrNull((t) => t.id == state.selectedTrackId);
    final clip = track?.clips.firstWhereOrNull((c) => c.id == state.selectedClipId);

    if (clip == null || clip.mediaPath == null) return;

    // Open selection UI
    if (mounted) {
      showGeneralDialog(
        context: context,
        pageBuilder: (context, anim1, anim2) {
          return AIMaskSelector(
            imageFile: File(clip.mediaPath!),
            resolution: state.project!.resolution,
            onCancel: () => Navigator.pop(context),
            onConfirmed: (points, boxes) async {
              Navigator.pop(context);

              setState(() {
                _isProcessing = true;
                _processStatus = 'AI Object Removal (LAMA)...';
                _progress = 0;
              });

              try {
                final aiService = AIService();
                final result = await aiService.removeObject(
                  clip.mediaPath!,
                  points: points,
                  boxes: boxes,
                );

                bloc.add(ReplaceClip(
                  trackId: state.selectedTrackId!,
                  clipId: state.selectedClipId!,
                  newMediaPath: result.path,
                ));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Object removed successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
                  );
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
          );
        },
      );
    }
  }

  Future<void> _autoBeatSync() async {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    final project = state.project;
    if (project == null) return;

    // Find first audio track and first video track
    final audioTrack = project.tracks.firstWhereOrNull((t) => t.type == TrackType.audio);
    final videoTrack = project.tracks.firstWhereOrNull((t) => t.type == TrackType.video);

    if (audioTrack == null || audioTrack.clips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an audio track to sync with')),
      );
      return;
    }
    if (videoTrack == null || videoTrack.clips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some video clips to sync')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = 'Analyzing Audio Beats...';
      _progress = 0;
    });

    try {
      final aiService = AIService();
      final audioClip = audioTrack.clips.first;
      if (audioClip.mediaPath == null) return;

      final beatResult = await aiService.detectBeats(
        audioClip.mediaPath!,
        onProgress: (p) => setState(() => _progress = p),
      );

      bloc.add(MatchCutToAudio(
        videoTrackId: videoTrack.id,
        audioTrackId: audioTrack.id,
        beatTimes: beatResult.beatTimes,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Synced video to ${beatResult.beatTimes.length} beats')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Beat Sync Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startSmartCutout() async {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;
    if (state.selectedClipId == null || state.selectedTrackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a clip to cutout')),
      );
      return;
    }

    final track = state.project?.tracks
        .firstWhereOrNull((t) => t.id == state.selectedTrackId);
    final clip = track?.clips.firstWhereOrNull((c) => c.id == state.selectedClipId);

    if (clip == null || clip.mediaPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected clip not found or has no media.')),
      );
      return;
    }

    // In a real app, we'd open a full-screen view to pick points.
    // For now, we'll simulate it with a center point.
    setState(() {
      _isProcessing = true;
      _processStatus = 'AI Smart Cutout...';
      _progress = 0;
    });

    try {
      final aiService = AIService();
      final result = await aiService.smartCutout(
        clip.mediaPath!,
        points: [const Offset(0.5, 0.5)], // Simulate center point selection
      );

      bloc.add(ReplaceClip(
        trackId: state.selectedTrackId!,
        clipId: state.selectedClipId!,
        newMediaPath: result.path,
        isAdjustmentLayer: clip.isAdjustmentLayer,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Smart Cutout completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Cutout Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _AIButton extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AIButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bg3.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

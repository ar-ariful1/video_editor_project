import 'dart:io';
import 'dart:ui' as ui show Clip;
import 'package:flutter/material.dart' hide Clip;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/models/video_project.dart';
import '../../../core/engine/timeline_engine.dart';
import '../../../app_theme.dart';

/// PreviewPlayer - High-performance preview engine using media_kit.
/// Synchronizes multiple video/audio layers based on the centralized TimelineModel.
class PreviewPlayer extends StatefulWidget {
  final VideoProject? project;
  final double currentTime;
  final bool isPlaying;
  final String? selectedClipId;

  const PreviewPlayer({
    super.key,
    required this.project,
    required this.currentTime,
    required this.isPlaying,
    this.selectedClipId,
  });

  @override
  State<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends State<PreviewPlayer> {
  // Map to manage active players for each clip on the timeline
  final Map<String, Player> _players = {};
  final Map<String, VideoController> _controllers = {};
  
  List<ResolvedClip> _activeClips = [];

  @override
  void initState() {
    super.initState();
    _syncTimeline();
  }

  @override
  void didUpdateWidget(PreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If project or time changes, re-resolve the timeline
    if (widget.project != oldWidget.project || widget.currentTime != oldWidget.currentTime) {
      _syncTimeline();
    }

    // Handle Play/Pause sync
    if (widget.isPlaying != oldWidget.isPlaying) {
      for (final player in _players.values) {
        if (widget.isPlaying) {
          player.play();
        } else {
          player.pause();
        }
      }
    }
  }

  void _syncTimeline() async {
    if (widget.project == null) return;

    // Get currently visible clips from our centralized engine
    final resolved = TimelineResolver.resolve(widget.project!, widget.currentTime);

    final activeIds = resolved.map((a) => a.clip.id).toSet();

    // 1. Initialize new players
    for (final active in resolved) {
      final clip = active.clip;
      if (clip.mediaPath != null && (clip.mediaType == 'video' || clip.mediaType == 'audio')) {
        if (!_players.containsKey(clip.id)) {
          final player = Player();
          _players[clip.id] = player;
          final controller = VideoController(player);
          _controllers[clip.id] = controller;

          await player.open(Media(clip.mediaPath!), play: widget.isPlaying);
          player.setRate(clip.speed); // Sync speed
          
          if (mounted) setState(() {}); // Trigger rebuild to show video
        }

        // 2. Critical: Synchronization (Seeking)
        final player = _players[clip.id];
        if (player != null) {
          final targetMs = (active.props.effectiveMediaTime * 1000).toInt();
          final currentMs = player.state.position.inMilliseconds;
          
          // Only seek if out of sync by more than 150ms to prevent jitter
          if ((currentMs - targetMs).abs() > 150) {
            player.seek(Duration(milliseconds: targetMs));
          }
          
          player.setVolume(active.props.volume * 100);
        }
      }
    }

    // 3. Cleanup unused players (Optimization)
    final toRemove = _players.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in toRemove) {
      final p = _players.remove(id);
      _controllers.remove(id);
      p?.dispose();
    }

    if (mounted) {
      setState(() {
        _activeClips = resolved;
      });
    }
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.project == null) return const Center(child: CircularProgressIndicator());

    final res = widget.project!.resolution;
    final aspectRatio = res.width / res.height;

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Render each resolved clip
              ..._activeClips.map((active) {
                final clip = active.clip;
                final props = active.props;

                Widget content;
                
                if (clip.mediaType == 'video') {
                  final controller = _controllers[clip.id];
                  content = controller != null ? Video(controller: controller) : const SizedBox.shrink();
                } else if (clip.isTextLayer && clip is TextLayer) {
                  content = Center(
                    child: Text(
                      clip.text,
                      style: TextStyle(
                        color: Color(clip.fill.colors.first),
                        fontSize: clip.fontSize,
                        fontFamily: clip.fontFamily,
                      ),
                    ),
                  );
                } else if (clip.mediaType == 'image') {
                  content = Image.file(File(clip.mediaPath!), fit: BoxFit.cover);
                } else {
                  content = const SizedBox.shrink();
                }

                // Apply Basic Visual Transforms from TimelineModel
                return Positioned(
                  left: (props.x * res.width).toDouble(),
                  top: (props.y * res.height).toDouble(),
                  width: (res.width * props.scaleX).toDouble(),
                  height: (res.height * props.scaleY).toDouble(),
                  child: Transform.rotate(
                    angle: props.rotation.toDouble() * 0.0174533, // Convert degrees to radians
                    child: Opacity(
                      opacity: props.opacity.clamp(0.0, 1.0).toDouble(),
                      child: content,
                    ),
                  ),
                );
              }),
              
              // Timecode Overlay
              _buildTimecode(widget.currentTime, res.frameRate),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimecode(double time, int fps) {
    final m = (time ~/ 60).toString().padLeft(2, '0');
    final s = (time % 60).toInt().toString().padLeft(2, '0');
    final f = ((time % 1) * fps).toInt().toString().padLeft(2, '0');
    
    return Positioned(
      bottom: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(4),
        color: Colors.black54,
        child: Text(
          '$m:$s:$f',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}

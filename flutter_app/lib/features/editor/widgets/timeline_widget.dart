// lib/features/editor/widgets/timeline_widget.dart
// Scrollable, zoomable, draggable multi-track timeline

import 'package:flutter/material.dart' hide Clip;
import 'dart:ui' as ui show Clip;
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../panels/transitions_panel.dart';
import '../../../app_theme.dart';

class TimelineWidget extends StatefulWidget {
  final VideoProject? project;
  final double currentTime;
  final double zoom; // pixels per second
  final String? selectedClipId;

  const TimelineWidget({
    super.key,
    required this.project,
    required this.currentTime,
    required this.zoom,
    this.selectedClipId,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  late final LinkedScrollControllerGroup _vScrollGroup;
  late final ScrollController _vScrollLabels;
  late final ScrollController _vScrollTracks;
  final ScrollController _hScroll = ScrollController();

  static const double _trackHeight = 44.0;
  static const double _labelWidth = 100.0;
  static const double _rulerHeight = 24.0;

  @override
  void initState() {
    super.initState();
    _vScrollGroup = LinkedScrollControllerGroup();
    _vScrollLabels = _vScrollGroup.addAndGet();
    _vScrollTracks = _vScrollGroup.addAndGet();
  }

  @override
  void dispose() {
    _vScrollLabels.dispose();
    _vScrollTracks.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TimelineWidget old) {
    super.didUpdateWidget(old);
    // Auto-scroll playhead into view
    if (isPlaying && widget.currentTime != old.currentTime) {
      _scrollToPlayhead();
    }
  }

  bool get isPlaying => context.read<TimelineBloc>().state.isPlaying;

  void _scrollToPlayhead() {
    final x = widget.currentTime * widget.zoom;
    final viewWidth = _hScroll.position.viewportDimension;
    if (x > _hScroll.offset + viewWidth * 0.8 || x < _hScroll.offset) {
      _hScroll.animateTo(
        (x - viewWidth * 0.3).clamp(0.0, _hScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    if (project == null) return const SizedBox.shrink();

    final duration = project.computedDuration;
    final totalWidth = _labelWidth + duration * widget.zoom + 200;
    final tracks = project.tracks;

    return Container(
      color: const Color(0xFF0A0A10),
      child: Row(children: [
        // Track labels
        SizedBox(
          width: _labelWidth,
          child: Column(children: [
            const SizedBox(height: _rulerHeight),
            Expanded(
              child: ReorderableListView(
                scrollController: _vScrollLabels,
                buildDefaultDragHandles: false,
                padding: EdgeInsets.zero,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex -= 1;
                  context.read<TimelineBloc>().add(
                      ReorderTrack(oldIndex: oldIndex, newIndex: newIndex));
                },
                children: [
                  for (int i = 0; i < tracks.length; i++)
                    _TrackLabel(
                      key: ValueKey(tracks[i].id),
                      track: tracks[i],
                      height: _trackHeight,
                      index: i,
                    ),
                ],
              ),
            ),
          ]),
        ),

        // Scrollable timeline body
        Expanded(
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                final bloc = context.read<TimelineBloc>();
                if (e.kind == PointerDeviceKind.trackpad &&
                    e.scrollDelta.dx == 0) {
                  // Pinch-zoom on trackpad
                  final factor = e.scrollDelta.dy > 0 ? 0.9 : 1.1;
                  bloc.add(SetZoom(widget.zoom * factor));
                } else {
                  _hScroll.jumpTo((_hScroll.offset + e.scrollDelta.dx)
                      .clamp(0, _hScroll.position.maxScrollExtent));
                }
              }
            },
            child: Stack(children: [
              // Tracks + clips
              SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Column(children: [
                    // Ruler
                    _TimelineRuler(
                      totalWidth: totalWidth,
                      zoom: widget.zoom,
                      duration: duration,
                      currentTime: widget.currentTime,
                    ),
                    // Track rows
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _vScrollTracks,
                        child: Stack(
                          children: [
                            Column(
                                children: tracks
                                    .map((track) => _TrackRow(
                                          track: track,
                                          zoom: widget.zoom,
                                          currentTime: widget.currentTime,
                                          selectedClipId: widget.selectedClipId,
                                          height: _trackHeight,
                                          totalWidth: totalWidth,
                                        ))
                                    .toList()),
                            if (project.beatTrack != null &&
                                project.beatTrack!.beats.isNotEmpty)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _BeatMarkerPainter(
                                      project.beatTrack!.beats,
                                      widget.zoom,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

          // Playhead (overlay)
          Positioned(
            left: (widget.currentTime * widget.zoom -
                (_hScroll.hasClients ? _hScroll.offset : 0)),
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                
                final localX = d.localPosition.dx;
                final newTime = ((_hScroll.offset + localX) / widget.zoom)
                    .clamp(0.0, duration);
                context.read<TimelineBloc>().add(SeekTo(newTime));
              },
              child: Stack(
                  clipBehavior: ui.Clip.none,
                children: [
                  _Playhead(
                      height: _rulerHeight + tracks.length * _trackHeight),
                  // Split feedback line
                  if (widget.selectedClipId != null)
                    _SplitFeedbackLine(
                      zoom: widget.zoom,
                      currentTime: widget.currentTime,
                      project: widget.project!,
                      selectedClipId: widget.selectedClipId!,
                      height: _rulerHeight + tracks.length * _trackHeight,
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    ),
  ]),
);
}
}

class _SplitFeedbackLine extends StatelessWidget {
final double zoom;
final double currentTime;
final VideoProject project;
final String selectedClipId;
final double height;

const _SplitFeedbackLine({
required this.zoom,
required this.currentTime,
required this.project,
required this.selectedClipId,
required this.height,
});

@override
Widget build(BuildContext context) {
Clip? selectedClip;
for (final track in project.tracks) {
  for (final clip in track.clips) {
    if (clip.id == selectedClipId) {
      selectedClip = clip;
      break;
    }
  }
}

if (selectedClip == null) return const SizedBox.shrink();

final canSplit =
    currentTime > selectedClip.startTime && currentTime < selectedClip.endTime;

if (!canSplit) return const SizedBox.shrink();

return Positioned(
  top: 0,
  bottom: 0,
  left: 0,
  child: Container(
    width: 2,
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.5),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          height: 4,
          width: 4,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    ),
  ),
);
}
}

// ── Ruler ─────────────────────────────────────────────────────────────────────

class _TimelineRuler extends StatelessWidget {
  final double totalWidth;
  final double zoom;
  final double duration;
  final double currentTime;

  const _TimelineRuler(
      {required this.totalWidth,
      required this.zoom,
      required this.duration,
      required this.currentTime});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        final t = d.localPosition.dx / zoom;
        context.read<TimelineBloc>().add(SeekTo(t.clamp(0.0, duration)));
      },
      onHorizontalDragUpdate: (d) {
        final t = d.localPosition.dx / zoom;
        context.read<TimelineBloc>().add(SeekTo(t.clamp(0.0, duration)));
      },
      child: CustomPaint(
        size: Size(totalWidth, 24),
        painter: _RulerPainter(zoom: zoom, duration: duration),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double zoom;
  final double duration;

  const _RulerPainter({required this.zoom, required this.duration});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF1A1A24);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final tickPaint = Paint()
      ..color = const Color(0xFF3A3A48)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Calculate tick interval based on zoom
    double tickInterval = 1.0; // seconds
    if (zoom < 30)
      tickInterval = 10;
    else if (zoom < 60)
      tickInterval = 5;
    else if (zoom < 100) tickInterval = 2;

    for (double t = 0; t <= duration + tickInterval; t += tickInterval) {
      final x = t * zoom;
      if (x > size.width) break;

      canvas.drawLine(
          Offset(x, size.height - 8), Offset(x, size.height), tickPaint);

      // Label
      final label = _formatTime(t);
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF5C5A78), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 2, 4));
    }
  }

  String _formatTime(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toInt().toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.zoom != zoom;
}

// ── Playhead ──────────────────────────────────────────────────────────────────

class _Playhead extends StatelessWidget {
  final double height;
  const _Playhead({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: height,
      child: Stack(children: [
        // Line
        Container(width: 2, height: height, color: const Color(0xFF7C6EF7)),
        // Diamond handle at top
        Positioned(
          top: 0,
          left: -6,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFF7C6EF7),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Track Label ───────────────────────────────────────────────────────────────

class _TrackLabel extends StatelessWidget {
  final Track track;
  final double height;
  final int index;

  const _TrackLabel({
    required this.track,
    required this.height,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = _trackColor(track.type);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        border: Border(bottom: BorderSide(color: const Color(0xFF2A2A38))),
      ),
      child: Row(children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.drag_indicator, size: 14, color: Color(0xFF5C5A78)),
          ),
        ),
        Container(width: 3, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            track.name,
            style: const TextStyle(
                color: Color(0xFF9D9BB8),
                fontSize: 10,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Mute button
        GestureDetector(
          onTap: () => context
              .read<TimelineBloc>()
              .add(UpdateTrack(track.copyWith(isMuted: !track.isMuted))),
          child: Icon(
            track.isMuted ? Icons.volume_off : Icons.volume_up,
            color: track.isMuted
                ? const Color(0xFF5C5A78)
                : const Color(0xFF9D9BB8),
            size: 14,
          ),
        ),
        const SizedBox(width: 6),
      ]),
    );
  }

  Color _trackColor(TrackType type) {
    switch (type) {
      case TrackType.video:
        return const Color(0xFF7C6EF7);
      case TrackType.audio:
        return const Color(0xFF4ECDC4);
      case TrackType.text:
        return const Color(0xFFF7C948);
      case TrackType.sticker:
        return const Color(0xFFF472B6);
      case TrackType.effect:
        return const Color(0xFFFB923C);
      case TrackType.adjustment:
        return const Color(0xFF4ADE80);
    }
  }
}

// ── Track Row ─────────────────────────────────────────────────────────────────

class _TrackRow extends StatelessWidget {
  final Track track;
  final double zoom;
  final double currentTime;
  final String? selectedClipId;
  final double height;
  final double totalWidth;

  const _TrackRow({
    required this.track,
    required this.zoom,
    required this.currentTime,
    required this.selectedClipId,
    required this.height,
    required this.totalWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: totalWidth,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E28))),
      ),
      child: Stack(children: [
        // Drop zone
        GestureDetector(
          onTapDown: (d) =>
              context.read<TimelineBloc>().add(const SelectClip()),
        ),
        // Clips
        ...track.clips.map((clip) => _ClipWidget(
              clip: clip,
              track: track,
              zoom: zoom,
              height: height,
              isSelected: clip.id == selectedClipId,
            )),
        // Gap Handles (Transitions)
        ..._buildGapHandles(context),
      ]),
    );
  }

  List<Widget> _buildGapHandles(BuildContext context) {
    if (track.type != TrackType.video && track.type != TrackType.audio) return [];

    final handles = <Widget>[];
    final clips = [...track.clips]..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (int i = 0; i < clips.length - 1; i++) {
      final current = clips[i];
      final next = clips[i + 1];

      // If clips are touching or very close, show a transition handle
      if ((next.startTime - current.endTime).abs() < 0.1) {
        handles.add(Positioned(
          left: current.endTime * zoom - 8,
          top: (height - 16) / 2,
          child: GestureDetector(
            onTap: () => _showTransitions(context, track.id, next.id, true),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
              ),
              child: const Icon(Icons.add, size: 12, color: Colors.black),
            ),
          ),
        ));
      }
    }
    return handles;
  }

  void _showTransitions(BuildContext context, String trackId, String clipId, bool isIn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransitionsPanel(
        trackId: trackId,
        clipId: clipId,
        isIn: isIn,
      ),
    );
  }
}

// ── Clip Widget ───────────────────────────────────────────────────────────────

class _ClipWidget extends StatefulWidget {
  final Clip clip;
  final Track track;
  final double zoom;
  final double height;
  final bool isSelected;

  const _ClipWidget(
      {required this.clip,
      required this.track,
      required this.zoom,
      required this.height,
      required this.isSelected});

  @override
  State<_ClipWidget> createState() => _ClipWidgetState();
}

class _ClipWidgetState extends State<_ClipWidget> {
  double _dragStartX = 0;
  double _dragStartTime = 0;

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final left = clip.startTime * widget.zoom;
    final width = clip.duration * widget.zoom;

    return Positioned(
      left: left,
      top: 2,
      height: widget.height - 4,
      width: width.clamp(4.0, double.infinity),
      child: GestureDetector(
        onTap: () => context
            .read<TimelineBloc>()
            .add(SelectClip(trackId: widget.track.id, clipId: clip.id)),
        onLongPress: () => _showClipMenu(context),
        onHorizontalDragStart: (d) {
          _dragStartX = d.globalPosition.dx;
          _dragStartTime = clip.startTime;
        },
        onHorizontalDragUpdate: (d) {
          if (widget.track.isLocked) return;
          final delta = (d.globalPosition.dx - _dragStartX) / widget.zoom;
          final newStart = (_dragStartTime + delta).clamp(0.0, double.infinity);
          context.read<TimelineBloc>().add(MoveClip(
                fromTrackId: widget.track.id,
                toTrackId: widget.track.id,
                clipId: clip.id,
                newStartTime: newStart,
              ));
        },
        child: _buildClipBody(),
      ),
    );
  }

  Widget _buildClipBody() {
    final clip = widget.clip;
    final isText = clip.isTextLayer;
    final isAudio = clip.mediaType == 'audio';
    final isOverlay = widget.track.zIndex > 1;

    Color color = AppTheme.videoAccent;
    if (isText) color = AppTheme.textAccent;
    else if (isAudio) color = AppTheme.audioAccent;
    else if (isOverlay) color = AppTheme.overlayAccent;

    final bgColor = color.withValues(alpha: widget.isSelected ? 0.6 : 0.35);
    final borderColor = widget.isSelected ? Colors.white : color.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: widget.isSelected ? 2 : 1),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: ui.Clip.hardEdge,
      child: Stack(
        children: [
          if (isAudio)
            Positioned.fill(
              child: CustomPaint(
                painter: _WaveformPainter(color: color.withValues(alpha: 0.5)),
              ),
            ),
          Row(children: [
            // Left Trim
            _TrimHandle(color: color, onDrag: (dx) {
              final delta = dx / widget.zoom;
              context.read<TimelineBloc>().add(TrimClip(
                trackId: widget.track.id,
                clipId: clip.id,
                newStartTime: (clip.startTime + delta).clamp(0.0, clip.endTime - 0.1),
              ));
            }),

            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Icon(
                      isText ? Icons.text_fields_rounded : (isAudio ? Icons.music_note_rounded : Icons.videocam_rounded),
                      size: 12,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isText ? (clip as TextLayer).text : (clip.mediaPath?.split('/').last ?? 'Clip'),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Trim
            _TrimHandle(color: color, onDrag: (dx) {
              final delta = dx / widget.zoom;
              context.read<TimelineBloc>().add(TrimClip(
                trackId: widget.track.id,
                clipId: clip.id,
                newEndTime: (clip.endTime + delta).clamp(clip.startTime + 0.1, double.infinity),
              ));
            }),
          ]),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    final step = 2.0;
    for (double i = 0; i < size.width; i += step) {
      final h = (size.height * 0.8) * (0.2 + (0.8 * (i % 7) / 7)); // Simulated waveform
      canvas.drawLine(
        Offset(i, (size.height - h) / 2),
        Offset(i, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => false;
}

class _BeatMarkerPainter extends CustomPainter {
  final List<Beat> beats;
  final double pixelsPerSecond;

  _BeatMarkerPainter(this.beats, this.pixelsPerSecond);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    for (final beat in beats) {
      final x = beat.time * pixelsPerSecond;
      if (x >= 0 && x <= size.width) {
        canvas.drawCircle(Offset(x, size.height - 4), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BeatMarkerPainter oldDelegate) =>
      beats != oldDelegate.beats || pixelsPerSecond != oldDelegate.pixelsPerSecond;
}

// ── Trim Handle ───────────────────────────────────────────────────────────────

extension _ClipWidgetStateMenu on _ClipWidgetState {
  void _showClipMenu(BuildContext context) {
    final bloc = context.read<TimelineBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      builder: (_) => Wrap(children: [
        _menuItem(Icons.auto_fix_high_rounded, 'In Transition', () {
          Navigator.pop(context);
          _showTransitions(context, widget.track.id, widget.clip.id, true);
        }),
        _menuItem(Icons.auto_fix_normal_rounded, 'Out Transition', () {
          Navigator.pop(context);
          _showTransitions(context, widget.track.id, widget.clip.id, false);
        }),
        _menuItem(Icons.content_cut_rounded, 'Split', () {
          bloc.add(SplitClip(trackId: widget.track.id, clipId: widget.clip.id));
          Navigator.pop(context);
        }),
        _menuItem(Icons.copy_rounded, 'Duplicate', () {
          bloc.add(
              DuplicateClip(trackId: widget.track.id, clipId: widget.clip.id));
          Navigator.pop(context);
        }),
        _menuItem(Icons.delete_sweep_rounded, 'Ripple Delete', () {
          bloc.add(
              RippleDelete(trackId: widget.track.id, clipId: widget.clip.id));
          Navigator.pop(context);
        }),
        _menuItem(Icons.delete_outline_rounded, 'Delete', () {
          bloc.add(
              RemoveClip(trackId: widget.track.id, clipId: widget.clip.id));
          Navigator.pop(context);
        }),
      ]),
    );
  }

  void _showTransitions(BuildContext context, String trackId, String clipId, bool isIn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransitionsPanel(
        trackId: trackId,
        clipId: clipId,
        isIn: isIn,
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: Icon(icon, color: const Color(0xFF9D9BB8)),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
      );
}

// ── Trim Handle ───────────────────────────────────────────────────────────────

class _TrimHandle extends StatelessWidget {
  final Color color;
  final void Function(double dx) onDrag;
  const _TrimHandle({required this.color, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: Container(
        width: 10,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(
          child: Container(
            width: 2,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}

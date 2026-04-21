// lib/features/editor/widgets/timeline_minimap.dart
// Timeline mini-map — overview for large projects + viewport indicator

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app_theme.dart';
import '../../../core/models/video_project.dart';
import '../../../core/repositories/project_repository.dart';

class TimelineMinimap extends StatelessWidget {
  final VideoProject? project;
  final double currentTime;
  final double viewStart;    // visible window start
  final double viewEnd;      // visible window end
  final ValueChanged<double>? onSeek;

  const TimelineMinimap({
    super.key, this.project, required this.currentTime,
    required this.viewStart, required this.viewEnd, this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    if (project == null) return const SizedBox.shrink();
    final duration = project!.computedDuration;
    if (duration <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTapDown: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final frac = d.localPosition.dx / box.size.width;
        onSeek?.call(frac * duration);
      },
      child: CustomPaint(
        size: const Size(double.infinity, 28),
        painter: _MinimapPainter(
          project: project!,
          duration: duration,
          currentTime: currentTime,
          viewStart: viewStart,
          viewEnd: viewEnd,
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final VideoProject project;
  final double duration, currentTime, viewStart, viewEnd;

  const _MinimapPainter({
    required this.project, required this.duration,
    required this.currentTime, required this.viewStart, required this.viewEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0A12));

    // Track lanes (compressed)
    final colors = [AppTheme.accent, AppTheme.accent2, AppTheme.green, AppTheme.accent3, AppTheme.pink];
    final visibleTracks = project.tracks.take(5).toList();
    final laneH = (size.height - 4) / visibleTracks.length.clamp(1, 5);

    for (int ti = 0; ti < visibleTracks.length; ti++) {
      final track = visibleTracks[ti];
      final color = colors[ti % colors.length];
      final y0    = 2 + ti * laneH;

      for (final clip in track.clips) {
        final x0 = clip.startTime / duration * size.width;
        final x1 = clip.endTime  / duration * size.width;
        canvas.drawRect(
          Rect.fromLTWH(x0, y0, (x1-x0).clamp(1, size.width), laneH - 1),
          Paint()..color = color.withValues(alpha: 0.6),
        );
      }
    }

    // Viewport indicator
    final vx0 = viewStart / duration * size.width;
    final vx1 = viewEnd   / duration * size.width;
    canvas.drawRect(
      Rect.fromLTWH(vx0, 0, vx1 - vx0, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(vx0, 0, vx1 - vx0, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1,
    );

    // Playhead
    final px = currentTime / duration * size.width;
    canvas.drawLine(Offset(px, 0), Offset(px, size.height), Paint()..color = AppTheme.accent..strokeWidth = 1.5);
    canvas.drawCircle(Offset(px, size.height / 2), 3, Paint()..color = AppTheme.accent);
  }

  @override
  bool shouldRepaint(_MinimapPainter old) =>
      old.currentTime != currentTime || old.viewStart != viewStart || old.viewEnd != viewEnd;
}

// ── Recently used fonts/stickers ──────────────────────────────────────────────

class RecentlyUsedService {
  static final RecentlyUsedService _i = RecentlyUsedService._();
  factory RecentlyUsedService() => _i;
  RecentlyUsedService._();

  static const _maxItems = 10;
  final _fonts    = <String>[];
  final _stickers = <String>[];
  final _effects  = <String>[];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _fonts.addAll(prefs.getStringList('recent_fonts')    ?? []);
    _stickers.addAll(prefs.getStringList('recent_stickers') ?? []);
    _effects.addAll(prefs.getStringList('recent_effects')  ?? []);
  }

  void addFont(String family) => _add(_fonts, family, 'recent_fonts');
  void addSticker(String id)  => _add(_stickers, id,   'recent_stickers');
  void addEffect(String name) => _add(_effects, name,  'recent_effects');

  List<String> get recentFonts    => List.unmodifiable(_fonts);
  List<String> get recentStickers => List.unmodifiable(_stickers);
  List<String> get recentEffects  => List.unmodifiable(_effects);

  void _add(List<String> list, String item, String key) async {
    list.remove(item);
    list.insert(0, item);
    if (list.length > _maxItems) list.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, list);
  }
}

// ── Project search (local) ────────────────────────────────────────────────────

class ProjectSearchService {
  static Future<List<VideoProject>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await ProjectRepository().getLocalProjects();
    final q   = query.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(q)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}

// ── Export history filter ─────────────────────────────────────────────────────

enum ExportHistoryFilter { all, success, failed, inProgress }

// ── Double-tap zoom preview ───────────────────────────────────────────────────

class ZoomablePreview extends StatefulWidget {
  final Widget child;
  const ZoomablePreview({super.key, required this.child});
  @override State<ZoomablePreview> createState() => _ZoomablePreviewState();
}

class _ZoomablePreviewState extends State<ZoomablePreview> {
  double _scale = 1.0;
  final _transformCtrl = TransformationController();

  void _handleDoubleTap() {
    if (_scale > 1.0) {
      _transformCtrl.value = Matrix4.identity();
      setState(() => _scale = 1.0);
    } else {
      _transformCtrl.value = Matrix4.identity()..scale(2.0, 2.0, 1.0);
      setState(() => _scale = 2.0);
    }
  }

  @override
  void dispose() { _transformCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTap: _handleDoubleTap,
    child: InteractiveViewer(
      transformationController: _transformCtrl,
      minScale: 0.5,
      maxScale: 4.0,
      child: widget.child,
    ),
  );
}


// lib/core/services/thumbnail_service.dart
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_project.dart';
import '../../app_theme.dart';
import 'native_engine_service.dart';

class ThumbnailService {
  static final ThumbnailService _i = ThumbnailService._();
  factory ThumbnailService() => _i;
  ThumbnailService._();

  // LRU cache: clipId_timeOffset → localPath
  final _cache = LinkedHashMap<String, String>(equals: (a,b) => a == b, hashCode: (k) => k.hashCode);
  static const _maxCacheSize = 500;

  /// Get thumbnail for a clip at specific time offset
  Future<String?> getThumb(String clipId, String videoPath, double timeSeconds) async {
    final key = '${clipId}_${timeSeconds.toStringAsFixed(1)}';
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final thumbPath = await NativeEngineService().getThumbnail(videoPath, timeSeconds);
      if (thumbPath != null) {
        _cache[key] = thumbPath;
        if (_cache.length > _maxCacheSize) _cache.remove(_cache.keys.first);
      }
      return thumbPath;
    } catch (_) {
      return null;
    }
  }

  /// Generate a strip of thumbnails for a clip (for timeline display)
  Future<List<String?>> getStrip(String clipId, String videoPath, double duration, {int count = 8}) async {
    final interval = duration / count;
    final futures = List.generate(count, (i) => getThumb(clipId, videoPath, i * interval));
    return Future.wait(futures);
  }

  void clearCache() => _cache.clear();

  /// Delete cached thumbnail files
  Future<void> purgeOldFiles() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync().whereType<File>().where((f) => f.path.contains('thumb_'));
    for (final f in files) {
      try {
        final mod = f.lastModifiedSync();
        if (DateTime.now().difference(mod).inHours > 24) f.deleteSync();
      } catch (_) {}
    }
  }
}

// ── Clip thumbnail strip widget ───────────────────────────────────────────────

class ClipThumbnailStrip extends StatefulWidget {
  final Clip clip;
  final double width;
  final double height;

  const ClipThumbnailStrip({super.key, required this.clip, required this.width, required this.height});

  @override
  State<ClipThumbnailStrip> createState() => _ClipThumbnailStripState();
}

class _ClipThumbnailStripState extends State<ClipThumbnailStrip> {
  List<String?> _thumbs = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.clip.mediaPath == null) return;
    final duration = widget.clip.endTime - widget.clip.startTime;
    final count = (widget.width / widget.height).ceil().clamp(2, 12);

    final thumbs = await ThumbnailService().getStrip(
      widget.clip.id,
      widget.clip.mediaPath!,
      duration,
      count: count,
    );
    if (mounted) setState(() { _thumbs = thumbs; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _thumbs.isEmpty) {
      return Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(color: AppTheme.bg3, borderRadius: BorderRadius.circular(4)),
        child: const Center(child: Icon(Icons.movie_rounded, color: AppTheme.textTertiary, size: 16)),
      );
    }

    return SizedBox(
      width: widget.width, height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(children: _thumbs.map((path) => Expanded(
          child: path != null
              ? Image.file(File(path), fit: BoxFit.cover, height: widget.height)
              : Container(color: AppTheme.bg3),
        )).toList()),
      ),
    );
  }
}

// lib/core/services/media_cache_manager.dart
// Full media cache — LRU eviction, duplicate detection, proxy management, memory budget

import 'dart:io';
import 'dart:collection';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class MediaCacheEntry {
  final String path;
  final int sizeBytes;
  final DateTime addedAt;
  int accessCount;
  DateTime lastAccessed;

  MediaCacheEntry({required this.path, required this.sizeBytes})
      : addedAt = DateTime.now(),
        lastAccessed = DateTime.now(),
        accessCount = 0;
}

class MediaCacheManager {
  static final MediaCacheManager _i = MediaCacheManager._();
  factory MediaCacheManager() => _i;
  MediaCacheManager._();

  // LRU cache: key → entry
  final _cache = LinkedHashMap<String, MediaCacheEntry>();
  final _hashIndex =
      <String, String>{}; // md5 → cache key (duplicate detection)

  int _totalBytes = 0;
  int maxBytes = 512 * 1024 * 1024; // 512 MB default

  // ── Thumbnail cache ───────────────────────────────────────────────────────────
  final _thumbCache = <String, Uint8List>{}; // key → JPEG bytes
  int _thumbBytes = 0;
  int maxThumbBytes = 64 * 1024 * 1024; // 64 MB

  // ── Add file to cache ─────────────────────────────────────────────────────────
  Future<String?> add(String sourcePath, {String? cacheKey}) async {
    final file = File(sourcePath);
    if (!file.existsSync()) return null;

    final size = file.lengthSync();
    final key = cacheKey ?? _keyFor(sourcePath);

    // Already cached?
    if (_cache.containsKey(key)) {
      final entry = _cache[key]!;
      entry.lastAccessed = DateTime.now();
      entry.accessCount++;
      _cache.remove(key);
      _cache[key] = entry; // move to front (most recent)
      return entry.path;
    }

    // Duplicate detection via MD5
    final hash = await _computeHash(file);
    if (_hashIndex.containsKey(hash)) {
      final existingKey = _hashIndex[hash]!;
      if (_cache.containsKey(existingKey)) return _cache[existingKey]!.path;
    }

    // Evict if over budget
    while (_totalBytes + size > maxBytes && _cache.isNotEmpty) {
      _evictLRU();
    }

    // Copy to cache dir
    final cacheDir = await _getCacheDir();
    final cachePath = '${cacheDir.path}/$key${_ext(sourcePath)}';
    await file.copy(cachePath);

    final entry = MediaCacheEntry(path: cachePath, sizeBytes: size);
    _cache[key] = entry;
    _hashIndex[hash] = key;
    _totalBytes += size;

    return cachePath;
  }

  // ── Get cached path ───────────────────────────────────────────────────────────
  String? get(String key) {
    if (!_cache.containsKey(key)) return null;
    final entry = _cache[key]!;
    entry.lastAccessed = DateTime.now();
    entry.accessCount++;
    _cache.remove(key);
    _cache[key] = entry;
    return entry.path;
  }

  // ── Thumbnail cache ───────────────────────────────────────────────────────────
  void cacheThumb(String key, Uint8List jpeg) {
    while (
        _thumbBytes + jpeg.length > maxThumbBytes && _thumbCache.isNotEmpty) {
      final oldest = _thumbCache.keys.first;
      _thumbBytes -= _thumbCache[oldest]!.length;
      _thumbCache.remove(oldest);
    }
    _thumbCache[key] = jpeg;
    _thumbBytes += jpeg.length;
  }

  Uint8List? getThumb(String key) => _thumbCache[key];

  bool hasThumb(String key) => _thumbCache.containsKey(key);

  // ── Duplicate detection ───────────────────────────────────────────────────────
  Future<String?> findDuplicate(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    final hash = await _computeHash(file);
    final key = _hashIndex[hash];
    if (key == null) return null;
    return _cache[key]?.path;
  }

  Future<String> _computeHash(File f) async {
    // Use first 64KB for fast hash (avoid hashing huge video files)
    const chunkSize = 64 * 1024;
    final bytes = f.lengthSync() > chunkSize
        ? (await f.openRead(0, chunkSize).toList()).expand((b) => b).toList()
        : await f.readAsBytes();
    return md5.convert(bytes).toString();
  }

  // ── Eviction ──────────────────────────────────────────────────────────────────
  void _evictLRU() {
    if (_cache.isEmpty) return;
    final lruKey = _cache.keys.first; // LinkedHashMap: first = oldest
    final entry = _cache.remove(lruKey)!;
    _totalBytes -= entry.sizeBytes;
    // Remove from hash index
    _hashIndex.removeWhere((_, v) => v == lruKey);
    // Delete from disk
    try {
      File(entry.path).deleteSync();
    } catch (_) {}
  }

  // ── Stats ─────────────────────────────────────────────────────────────────────
  int get cachedFiles => _cache.length;
  int get usedBytes => _totalBytes;
  double get usedMB => _totalBytes / 1024 / 1024;
  int get thumbCachedFiles => _thumbCache.length;

  String get usageString =>
      '${usedMB.toStringAsFixed(1)} MB / ${(maxBytes / 1024 / 1024).toStringAsFixed(0)} MB';

  // ── Clear ─────────────────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    for (final entry in _cache.values) {
      try {
        File(entry.path).deleteSync();
      } catch (_) {}
    }
    _cache.clear();
    _hashIndex.clear();
    _thumbCache.clear();
    _totalBytes = 0;
    _thumbBytes = 0;
  }

  Future<void> clearOldFiles(
      {Duration maxAge = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final toRemove = <String>[];
    for (final entry in _cache.entries) {
      if (entry.value.lastAccessed.isBefore(cutoff)) toRemove.add(entry.key);
    }
    for (final key in toRemove) {
      final entry = _cache.remove(key);
      if (entry != null) {
        _totalBytes -= entry.sizeBytes;
        try {
          File(entry.path).deleteSync();
        } catch (_) {}
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  String _keyFor(String path) => path
      .replaceAll(RegExp(r'[^\w]'), '_')
      .substring(path.length > 50 ? path.length - 50 : 0);
  String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i >= 0 ? path.substring(i) : '';
  }

  Future<Directory> _getCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/media_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}

// ── Memory optimizer ──────────────────────────────────────────────────────────

class MemoryOptimizer {
  static final MemoryOptimizer _i = MemoryOptimizer._();
  factory MemoryOptimizer() => _i;
  MemoryOptimizer._();

  bool lowMemoryMode = false;

  void onLowMemoryWarning() {
    lowMemoryMode = true;
    // Clear thumbnail cache
    MediaCacheManager().clearOldFiles(maxAge: Duration.zero);
    // Reduce video buffer size in native engine
    // NativeEngineService().setLowMemoryMode(true);
  }

  void onMemoryNormal() {
    lowMemoryMode = false;
    // NativeEngineService().setLowMemoryMode(false);
  }

  // Preview quality based on available memory
  int get previewWidth => lowMemoryMode ? 540 : 1080;
  int get previewHeight => lowMemoryMode ? 960 : 1920;
  int get previewFps => lowMemoryMode ? 15 : 30;
  int get videoBufferFrames => lowMemoryMode ? 4 : 16;
}

// lib/core/services/asset_loader_service.dart
// Dynamic asset loading — fonts, sticker packs, safe export names, copyright detection

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

// ── Dynamic font loader ───────────────────────────────────────────────────────

class DynamicFontLoader {
  static final DynamicFontLoader _i = DynamicFontLoader._();
  factory DynamicFontLoader() => _i;
  DynamicFontLoader._();

  final _loaded = <String, bool>{}; // fontFamily → loaded
  final _dio = Dio();

  static const _cdnBase = String.fromEnvironment('CDN_DOMAIN',
      defaultValue: 'https://cdn.videoeditorpro.app');

  /// Load font from CDN and register with Flutter
  Future<bool> loadFont(String fontFamily, String cdnPath) async {
    if (_loaded[fontFamily] == true) return true;

    try {
      final dir = await getApplicationSupportDirectory();
      final file =
          File('${dir.path}/fonts/${fontFamily.replaceAll(' ', '_')}.ttf');

      // Download if not cached
      if (!file.existsSync()) {
        file.parent.createSync(recursive: true);
        final url = cdnPath.startsWith('http') ? cdnPath : '$_cdnBase/$cdnPath';
        await _dio.download(url, file.path);
      }

      // Register with Flutter font system
      final bytes = await file.readAsBytes();
      final fontData = ByteData.view(bytes.buffer);
      final loader = FontLoader(fontFamily);
      loader.addFont(Future.value(fontData));
      await loader.load();

      _loaded[fontFamily] = true;
      debugPrint('✅ Font loaded: $fontFamily');
      return true;
    } catch (e) {
      debugPrint('❌ Font load failed: $fontFamily — $e');
      return false;
    }
  }

  bool isLoaded(String fontFamily) => _loaded[fontFamily] == true;

  /// Load multiple fonts in parallel
  Future<Map<String, bool>> loadFonts(Map<String, String> fontMap) async {
    final futures = fontMap.entries
        .map((e) => loadFont(e.key, e.value).then((ok) => MapEntry(e.key, ok)));
    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }

  // Common fonts pre-cached
  static const defaultFonts = {
    'Inter': 'fonts/Inter-Regular.ttf',
    'Playfair Display': 'fonts/PlayfairDisplay-Regular.ttf',
    'Montserrat': 'fonts/Montserrat-Regular.ttf',
    'Dancing Script': 'fonts/DancingScript-Regular.ttf',
    'Bebas Neue': 'fonts/BebasNeue-Regular.ttf',
    'Oswald': 'fonts/Oswald-Regular.ttf',
    'Roboto Mono': 'fonts/RobotoMono-Regular.ttf',
    'Pacifico': 'fonts/Pacifico-Regular.ttf',
    'Lobster': 'fonts/Lobster-Regular.ttf',
    'Raleway': 'fonts/Raleway-Regular.ttf',
    'Anton': 'fonts/Anton-Regular.ttf',
    'Comfortaa': 'fonts/Comfortaa-Regular.ttf',
  };
}

// ── Sticker pack loader ───────────────────────────────────────────────────────

class StickerPack {
  final String id, name, category, thumbnailUrl;
  final int stickerCount;
  final bool isPremium, isDownloaded;
  const StickerPack(
      {required this.id,
      required this.name,
      required this.category,
      required this.thumbnailUrl,
      required this.stickerCount,
      this.isPremium = false,
      this.isDownloaded = false});
}

class StickerPackLoader {
  static final StickerPackLoader _i = StickerPackLoader._();
  factory StickerPackLoader() => _i;
  StickerPackLoader._();

  final _downloaded =
      <String, List<String>>{}; // packId → [local sticker paths]
  final _dio = Dio();

  Future<bool> downloadPack(String packId, String packUrl,
      {void Function(double)? onProgress}) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final packDir = Directory('${dir.path}/stickers/$packId');
      packDir.createSync(recursive: true);

      // Download zip, extract stickers
      final zipPath = '${packDir.path}/pack.zip';
      await _dio.download(packUrl, zipPath, onReceiveProgress: (rcv, total) {
        if (total > 0) onProgress?.call(rcv / total);
      });

      // In production: use archive package to extract zip
      // final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
      // for (final file in archive) { ... extract ... }

      _downloaded[packId] = [];
      return true;
    } catch (e) {
      debugPrint('Sticker pack download failed: $e');
      return false;
    }
  }

  bool isDownloaded(String packId) => _downloaded.containsKey(packId);
  List<String> getStickerPaths(String packId) => _downloaded[packId] ?? [];
}

// ── Music copyright detector ──────────────────────────────────────────────────

class MusicLicenseInfo {
  final String trackId;
  final bool isRoyaltyFree, isCopyrighted, isCreativeCommons;
  final String? licenseType;
  final List<String> restrictedPlatforms;

  const MusicLicenseInfo({
    required this.trackId,
    required this.isRoyaltyFree,
    required this.isCopyrighted,
    required this.isCreativeCommons,
    this.licenseType,
    this.restrictedPlatforms = const [],
  });

  bool get canUseOnYouTube => !restrictedPlatforms.contains('youtube');
  bool get canUseOnTikTok => !restrictedPlatforms.contains('tiktok');
  bool get canUseOnInstagram => !restrictedPlatforms.contains('instagram');

  String get safetyLabel {
    if (isRoyaltyFree) return '✅ Royalty Free';
    if (isCreativeCommons) return '🔵 Creative Commons';
    if (isCopyrighted) return '⚠️ Copyright — check license';
    return '❓ Unknown';
  }

  Color get safetyColor {
    if (isRoyaltyFree) return const Color(0xFF4ade80);
    if (isCreativeCommons) return const Color(0xFF60a5fa);
    return const Color(0xFFfbbf24);
  }
}

class MusicLicenseService {
  static const _licensedTracks = <String>{}; // IDs of our royalty-free tracks

  static MusicLicenseInfo checkLicense(String trackId, {String? source}) {
    // Our library = always royalty-free
    if (_licensedTracks.contains(trackId) || source == 'library') {
      return MusicLicenseInfo(
          trackId: trackId,
          isRoyaltyFree: true,
          isCopyrighted: false,
          isCreativeCommons: false,
          licenseType: 'Video Editor Pro Library');
    }

    // User-imported music — assume copyrighted (conservative)
    return MusicLicenseInfo(
      trackId: trackId,
      isRoyaltyFree: false,
      isCopyrighted: true,
      isCreativeCommons: false,
      licenseType: 'Unknown',
      restrictedPlatforms: ['youtube', 'tiktok', 'instagram'],
    );
  }
}

// ── Safe export file naming ───────────────────────────────────────────────────

class SafeExportNaming {
  /// Generate unique, safe filename
  static Future<String> generate(
      String projectName, String quality, String ext) async {
    // Sanitize: remove special chars, limit length
    String safe = projectName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (safe.length > 40) safe = safe.substring(0, 40);
    if (safe.isEmpty) safe = 'video';

    final ts = DateTime.now().millisecondsSinceEpoch;
    final base = '${safe}_${quality}_$ts';

    // Check for existing file
    final dir = await getApplicationDocumentsDirectory();
    String path = '${dir.path}/$base$ext';
    int counter = 1;
    while (File(path).existsSync()) {
      path = '${dir.path}/${base}_$counter$ext';
      counter++;
    }
    return path;
  }

  /// Sanitize user input for file names
  static String sanitize(String input) => input
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
}

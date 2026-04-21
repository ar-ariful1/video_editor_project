// lib/core/services/social_export_service.dart
// Social platform export optimizer — bitrate presets, captions, deep link share

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../app_theme.dart';

// ── Platform export presets ───────────────────────────────────────────────────

class SocialPlatformPreset {
  final String name;
  final IconData icon;
  final int width, height, fps;
  final int videoBitrateKbps, audioBitrateKbps;
  final String codec; // h264 | h265
  final int maxDurationSec;
  final int maxFileMB;
  final String recommendedRatio;

  const SocialPlatformPreset({
    required this.name, required this.icon,
    required this.width, required this.height, required this.fps,
    required this.videoBitrateKbps, required this.audioBitrateKbps,
    required this.codec, required this.maxDurationSec, required this.maxFileMB,
    required this.recommendedRatio,
  });

  int get estimatedSizeMB {
    const bitsPerMB = 8 * 1024 * 1024;
    final bitrateTotal = videoBitrateKbps * 1000 + audioBitrateKbps * 1000;
    return (bitrateTotal * maxDurationSec / bitsPerMB).ceil();
  }
}

class SocialPresets {
  // TikTok: 9:16, up to 60s, max 287.6MB, H.264
  static const tiktok = SocialPlatformPreset(
    name: 'TikTok', icon: Icons.music_note_rounded,
    width: 1080, height: 1920, fps: 30,
    videoBitrateKbps: 8000, audioBitrateKbps: 192,
    codec: 'h264', maxDurationSec: 180, maxFileMB: 287,
    recommendedRatio: '9:16',
  );

  // Instagram Reels: 9:16, up to 90s, max 1GB
  static const instagramReels = SocialPlatformPreset(
    name: 'Instagram Reels', icon: Icons.camera_alt_rounded,
    width: 1080, height: 1920, fps: 30,
    videoBitrateKbps: 6000, audioBitrateKbps: 192,
    codec: 'h264', maxDurationSec: 90, maxFileMB: 500,
    recommendedRatio: '9:16',
  );

  // YouTube Shorts: 9:16, up to 60s
  static const youtubeShorts = SocialPlatformPreset(
    name: 'YouTube Shorts', icon: Icons.play_circle_fill_rounded,
    width: 1080, height: 1920, fps: 60,
    videoBitrateKbps: 10000, audioBitrateKbps: 256,
    codec: 'h264', maxDurationSec: 60, maxFileMB: 500,
    recommendedRatio: '9:16',
  );

  // Facebook: 16:9 or 4:5
  static const facebook = SocialPlatformPreset(
    name: 'Facebook', icon: Icons.facebook_rounded,
    width: 1280, height: 720, fps: 30,
    videoBitrateKbps: 4000, audioBitrateKbps: 128,
    codec: 'h264', maxDurationSec: 240, maxFileMB: 1000,
    recommendedRatio: '16:9',
  );

  // WhatsApp Status: 9:16, up to 30s, max 16MB
  static const whatsappStatus = SocialPlatformPreset(
    name: 'WhatsApp Status', icon: Icons.chat_bubble_rounded,
    width: 720, height: 1280, fps: 30,
    videoBitrateKbps: 2000, audioBitrateKbps: 128,
    codec: 'h264', maxDurationSec: 30, maxFileMB: 16,
    recommendedRatio: '9:16',
  );

  // High quality master
  static const master = SocialPlatformPreset(
    name: 'Master Copy (4K)', icon: Icons.workspace_premium_rounded,
    width: 2160, height: 3840, fps: 60,
    videoBitrateKbps: 40000, audioBitrateKbps: 320,
    codec: 'h265', maxDurationSec: 3600, maxFileMB: 5000,
    recommendedRatio: '9:16',
  );

  static const all = [tiktok, instagramReels, youtubeShorts, facebook, whatsappStatus, master];
}

// ── Auto caption suggestion ───────────────────────────────────────────────────

class CaptionSuggestion {
  final String text, hashtags;
  const CaptionSuggestion({required this.text, required this.hashtags});
}

class AutoCaptionService {
  static List<CaptionSuggestion> suggest({
    required String templateCategory,
    required String projectName,
  }) {
    final catSuggestions = <String, List<CaptionSuggestion>>{
      'wedding': [
        CaptionSuggestion(text: 'Love is in the air', hashtags: '#wedding #love #forever #bride'),
        CaptionSuggestion(text: 'Our perfect day', hashtags: '#weddingday #weddingvideo #newlyweds'),
      ],
      'travel': [
        CaptionSuggestion(text: 'Adventure awaits', hashtags: '#travel #wanderlust #explore #vacation'),
        CaptionSuggestion(text: 'Making memories', hashtags: '#travelgram #travelvlog #adventure'),
      ],
      'food': [
        CaptionSuggestion(text: 'Taste the moment', hashtags: '#foodie #foodvideo #delicious #recipe'),
        CaptionSuggestion(text: 'Food that hits different', hashtags: '#food #cooking #foodlover'),
      ],
      'business': [
        CaptionSuggestion(text: 'Elevate your brand', hashtags: '#business #marketing #entrepreneur'),
        CaptionSuggestion(text: 'Growth mindset', hashtags: '#startup #success #businessvideo'),
      ],
      'islamic': [
        CaptionSuggestion(text: 'بسم الله الرحمن الرحيم', hashtags: '#islamic #quran #muslim #islam'),
        CaptionSuggestion(text: 'Alhamdulillah', hashtags: '#islamicvideo #deen #faith'),
      ],
    };

    return catSuggestions[templateCategory.toLowerCase()] ?? [
      CaptionSuggestion(text: 'Made with ClipCut', hashtags: '#clipcut #reels #viral'),
      CaptionSuggestion(text: 'Creating something special', hashtags: '#video #creative #content'),
    ];
  }
}

// ── Social export optimizer ───────────────────────────────────────────────────

class SocialExportOptimizer {
  /// Get recommended preset for platform
  static SocialPlatformPreset presetFor(String platform) {
    switch (platform.toLowerCase()) {
      case 'tiktok':     return SocialPresets.tiktok;
      case 'instagram':  return SocialPresets.instagramReels;
      case 'youtube':    return SocialPresets.youtubeShorts;
      case 'facebook':   return SocialPresets.facebook;
      case 'whatsapp':   return SocialPresets.whatsappStatus;
      default:           return SocialPresets.tiktok;
    }
  }

  /// Warn if video duration exceeds platform limit
  static String? durationWarning(String platform, double durationSec) {
    final preset = presetFor(platform);
    if (durationSec > preset.maxDurationSec) {
      return '⚠️ ${preset.name} max duration is ${preset.maxDurationSec}s. Your video is ${durationSec.toInt()}s.';
    }
    return null;
  }

  /// Warn if estimated file size exceeds limit
  static String? sizeWarning(String platform, int estimatedMB) {
    final preset = presetFor(platform);
    if (estimatedMB > preset.maxFileMB) {
      return '⚠️ ${preset.name} max file size is ${preset.maxFileMB}MB. Estimated: ${estimatedMB}MB.';
    }
    return null;
  }

  /// Generate share caption for platform
  static String generateDeepLink(String projectId) =>
    'https://videoeditorpro.app/watch/$projectId';

  static Future<void> shareWithCaption({
    required String videoPath,
    required String platform,
    required String caption,
    String? deepLink,
  }) async {
    final shareText = deepLink != null ? '$caption\n\nMade with Video Editor Pro: $deepLink' : caption;
    await Share.shareXFiles(
      [XFile(videoPath)],
      subject: shareText,
    );
  }
}

// ── Platform selector widget ──────────────────────────────────────────────────

class PlatformExportSelector extends StatefulWidget {
  final void Function(SocialPlatformPreset) onSelected;
  const PlatformExportSelector({super.key, required this.onSelected});
  @override State<PlatformExportSelector> createState() => _PlatformExportSelectorState();
}

class _PlatformExportSelectorState extends State<PlatformExportSelector> {
  SocialPlatformPreset? _selected;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Optimize for Platform', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    const SizedBox(height: 10),
    Wrap(spacing: 8, runSpacing: 8, children: SocialPresets.all.map((preset) {
      final sel = _selected?.name == preset.name;
      return GestureDetector(
        onTap: () { setState(() => _selected = preset); widget.onSelected(preset); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppTheme.accent : AppTheme.border),
          ),
          child: Column(children: [
            Icon(preset.icon, color: sel ? AppTheme.accent : AppTheme.textSecondary, size: 24),
            const SizedBox(height: 4),
            Text(preset.name.split(' ').first, style: TextStyle(color: sel ? AppTheme.accent : AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
            Text('${preset.recommendedRatio} · ${preset.fps}fps', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
          ]),
        ),
      );
    }).toList()),
  ]);
}

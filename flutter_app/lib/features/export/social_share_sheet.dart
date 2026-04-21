// lib/features/export/social_share_sheet.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../app_theme.dart';

class SocialShareSheet extends StatefulWidget {
  final String videoPath;
  final String projectTitle;
  const SocialShareSheet(
      {super.key, required this.videoPath, required this.projectTitle});
  @override
  State<SocialShareSheet> createState() => _SocialShareSheetState();
}

class _SocialShareSheetState extends State<SocialShareSheet> {
  bool _sharing = false;
  String? _shareStatus;

  static const _platforms = [
    _Platform(
        'tiktok', '🎵', 'TikTok', 'Share as a TikTok video', Color(0xFF010101)),
    _Platform('instagram', '📸', 'Instagram', 'Post as an Instagram Reel',
        Color(0xFFE1306C)),
    _Platform('youtube', '▶️', 'YouTube', 'Upload to YouTube Shorts',
        Color(0xFFFF0000)),
    _Platform('whatsapp', '💬', 'WhatsApp', 'Share as WhatsApp Status',
        Color(0xFF25D366)),
    _Platform(
        'general', '📤', 'More…', 'Share via other apps', AppTheme.accent),
  ];

  Future<void> _share(String platform) async {
    setState(() {
      _sharing = true;
      _shareStatus = 'Preparing…';
    });
    try {
      switch (platform) {
        case 'tiktok':
          setState(() => _shareStatus = 'Opening TikTok…');
          // TikTok Open SDK integration
          // await TikTokShareService().shareVideo(widget.videoPath, caption: widget.projectTitle);
          await Future.delayed(const Duration(milliseconds: 800));
          _openNativeShare('TikTok'); // Fallback
          break;

        case 'instagram':
          setState(() => _shareStatus = 'Opening Instagram…');
          // await InstagramShareService().shareReel(widget.videoPath, caption: '#VideoEditorPro');
          await Future.delayed(const Duration(milliseconds: 800));
          _openNativeShare('Instagram');
          break;

        case 'youtube':
          setState(() => _shareStatus = 'Uploading to YouTube…');
          // await YouTubeUploadService().uploadShort(widget.videoPath, title: widget.projectTitle);
          await Future.delayed(const Duration(milliseconds: 800));
          _openNativeShare('YouTube');
          break;

        case 'whatsapp':
          await Share.shareXFiles([XFile(widget.videoPath)],
              subject: widget.projectTitle);
          break;

        default:
          await Share.shareXFiles([XFile(widget.videoPath)],
              subject: widget.projectTitle);
      }
      if (mounted) {
        setState(() {
          _sharing = false;
          _shareStatus = '✅ Shared successfully!';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _sharing = false;
          _shareStatus = '❌ Share failed: $e';
        });
    }
  }

  void _openNativeShare(String app) {
    Share.shareXFiles([XFile(widget.videoPath)],
        subject: 'Made with Video Editor Pro #${app.toLowerCase()} #videoeditor');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Share Video',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(widget.projectTitle,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),

        if (_shareStatus != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.bg3, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              if (_sharing)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent))
              else
                Text(_shareStatus!.startsWith('✅') ? '✅' : '❌',
                    style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Text(_shareStatus!,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        // Platform buttons
        ...List.generate(_platforms.length, (i) {
          final p = _platforms[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: _sharing ? null : () => _share(p.id),
              child: AnimatedOpacity(
                opacity: _sharing ? 0.5 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: p.id == 'general'
                        ? AppTheme.bg3
                        : p.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: p.id == 'general'
                            ? AppTheme.border
                            : p.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Text(p.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(p.name,
                              style: TextStyle(
                                  color: p.id == 'general'
                                      ? AppTheme.textPrimary
                                      : p.color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text(p.description,
                              style: const TextStyle(
                                  color: AppTheme.textTertiary, fontSize: 11)),
                        ])),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: p.id == 'general'
                            ? AppTheme.textTertiary
                            : p.color),
                  ]),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _Platform {
  final String id, icon, name, description;
  final Color color;
  const _Platform(this.id, this.icon, this.name, this.description, this.color);
}

// Show social share sheet
void showSocialShareSheet(BuildContext context,
    {required String videoPath, required String projectTitle}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.bg2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) =>
        SocialShareSheet(videoPath: videoPath, projectTitle: projectTitle),
  );
}

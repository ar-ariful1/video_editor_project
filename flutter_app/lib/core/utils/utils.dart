// lib/core/utils/utils.dart
import 'package:flutter/material.dart';
import '../../app_theme.dart';

String formatDuration(double s) {
  final m = (s / 60).floor();
  final sec = (s % 60).floor();
  return m > 0 ? '${m}m ${sec}s' : '${sec}s';
}

String formatTimecode(double s, int fps) {
  final tf = (s * fps).floor();
  final f = tf % fps;
  final sec = (tf ~/ fps) % 60;
  final m = (tf ~/ fps ~/ 60) % 60;
  final h = tf ~/ fps ~/ 3600;
  return h > 0
      ? '${_p(h)}:${_p(m)}:${_p(sec)}:${_p(f)}'
      : '${_p(m)}:${_p(sec)}:${_p(f)}';
}

String _p(int n) => n.toString().padLeft(2, '0');
String formatRelativeTime(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
  return '${(d.inDays / 30).floor()}mo ago';
}

String formatFileSize(int b) {
  if (b < 1024) return '${b}B';
  if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)}KB';
  if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)}MB';
  return '${(b / 1073741824).toStringAsFixed(2)}GB';
}

bool isValidEmail(String e) =>
    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(e.trim());
bool isStrongPassword(String p) =>
    p.length >= 8 &&
    RegExp(r'[A-Z]').hasMatch(p) &&
    RegExp(r'[0-9]').hasMatch(p);
String truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';
String colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
Color hexColor(String h) {
  h = h.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

Future<bool?> showConfirmDialog(BuildContext ctx,
        {required String title,
        required String message,
        String confirmLabel = 'Confirm',
        Color? confirmColor}) async =>
    showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
                backgroundColor: AppTheme.bg2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                content: Text(message,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppTheme.textTertiary))),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor ?? AppTheme.accent),
                      child: Text(confirmLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)))
                ]));

void showSuccess(BuildContext ctx, String msg) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13)))
      ]),
      backgroundColor: AppTheme.bg3,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3)));
}

void showError(BuildContext ctx, String msg) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppTheme.accent4, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13)))
      ]),
      backgroundColor: AppTheme.bg3,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4)));
}

void showInfo(BuildContext ctx, String msg) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
      backgroundColor: AppTheme.bg3,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2)));
}

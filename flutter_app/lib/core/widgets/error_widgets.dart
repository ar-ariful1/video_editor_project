// lib/core/widgets/error_widgets.dart
// Reusable error handling UI components

import 'package:flutter/material.dart';
import '../../app_theme.dart';

// ── Network Error ──────────────────────────────────────────────────────────────
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;
  const NetworkErrorWidget({super.key, this.onRetry, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppTheme.accent4.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppTheme.accent4, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No Internet Connection',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message ?? 'Please check your connection and try again.',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      );
}

// ── Upload Error ──────────────────────────────────────────────────────────────
class UploadErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;
  const UploadErrorBanner(
      {super.key,
      required this.message,
      this.onRetry,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.accent4.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent4.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.accent4, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Upload Failed',
                    style: TextStyle(
                        color: AppTheme.accent4,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(message,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ])),
          if (onRetry != null)
            TextButton(
                onPressed: onRetry,
                child: const Text('Retry',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
          IconButton(
              icon: const Icon(Icons.close,
                  color: AppTheme.textTertiary, size: 16),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ]),
      );
}

// ── Export Error ──────────────────────────────────────────────────────────────
class ExportErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  final VoidCallback onClose;
  const ExportErrorWidget(
      {super.key, required this.error, this.onRetry, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent4.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cancel_rounded, color: AppTheme.accent4, size: 48),
          const SizedBox(height: 14),
          const Text('Export Failed',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (onRetry != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Export',
                      style: TextStyle(fontWeight: FontWeight.w700))),
            ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: onClose,
              child: const Text('Close',
                  style: TextStyle(color: AppTheme.textTertiary))),
        ]),
      );
}

// ── Generic empty state ────────────────────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ]),
        ),
      );
}

// ── Loading skeleton ───────────────────────────────────────────────────────────
class SkeletonBox extends StatefulWidget {
  final double width, height;
  final double radius;
  const SkeletonBox(
      {super.key, required this.width, required this.height, this.radius = 8});
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.bg3.withValues(alpha: _anim.value + 0.3),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

// ── Loading overlay ───────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final String? message;
  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
                color: AppTheme.bg2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 3),
              if (message != null) ...[
                const SizedBox(height: 14),
                Text(message!,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14)),
              ],
            ]),
          ),
        ),
      );
}

// ── Success toast ─────────────────────────────────────────────────────────────
void showSuccessToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 18),
      const SizedBox(width: 10),
      Expanded(
          child: Text(message,
              style: const TextStyle(color: AppTheme.textPrimary))),
    ]),
    backgroundColor: AppTheme.bg3,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: const Duration(seconds: 3),
  ));
}

void showErrorToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: AppTheme.accent4, size: 18),
      const SizedBox(width: 10),
      Expanded(
          child: Text(message,
              style: const TextStyle(color: AppTheme.textPrimary))),
    ]),
    backgroundColor: AppTheme.bg3,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: const Duration(seconds: 4),
  ));
}

void showInfoToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message, style: const TextStyle(color: AppTheme.textPrimary)),
    backgroundColor: AppTheme.bg3,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}

// lib/core/widgets/loading_widgets.dart
// All loading states, skeletons, and empty states
import 'package:flutter/material.dart';
import '../../app_theme.dart';

// ── Skeleton shimmer ──────────────────────────────────────────────────────────
class Skeleton extends StatefulWidget {
  final double width, height, radius;
  const Skeleton(
      {super.key, required this.width, required this.height, this.radius = 8});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
        animation: _a,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppTheme.bg3, const Color(0xFF2E2E3C), _a.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

// ── Template grid skeleton ─────────────────────────────────────────────────────
class TemplateGridSkeleton extends StatelessWidget {
  final int count;
  const TemplateGridSkeleton({super.key, this.count = 6});
  @override
  Widget build(BuildContext ctx) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            const Expanded(
                child: Skeleton(
                    width: double.infinity,
                    height: double.infinity,
                    radius: 11)),
            Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Skeleton(width: double.infinity, height: 13, radius: 4),
                  const SizedBox(height: 6),
                  Skeleton(width: 80, height: 10, radius: 4),
                ])),
          ]),
        ),
      );
}

// ── Project list skeleton ─────────────────────────────────────────────────────
class ProjectListSkeleton extends StatelessWidget {
  final int count;
  const ProjectListSkeleton({super.key, this.count = 3});
  @override
  Widget build(BuildContext ctx) => Column(
        children: List.generate(
            count,
            (_) => Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border)),
                  child: const Row(children: [
                    Skeleton(width: 52, height: 52, radius: 8),
                    SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Skeleton(width: 140, height: 13, radius: 4),
                          SizedBox(height: 6),
                          Skeleton(width: 100, height: 10, radius: 4),
                        ])),
                  ]),
                )),
      );
}

// ── Full screen loading ───────────────────────────────────────────────────────
class FullScreenLoading extends StatelessWidget {
  final String? message;
  const FullScreenLoading({super.key, this.message});
  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 3),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ])),
      );
}

// ── Export loading overlay ────────────────────────────────────────────────────
class ExportLoadingWidget extends StatefulWidget {
  final double progress;
  final VoidCallback? onCancel;
  const ExportLoadingWidget({super.key, required this.progress, this.onCancel});
  @override
  State<ExportLoadingWidget> createState() => _ExportLoadingWidgetState();
}

class _ExportLoadingWidgetState extends State<ExportLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                    value: widget.progress,
                    strokeWidth: 5,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accent))),
            Text('${(widget.progress * 100).toInt()}%',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          const Text('Exporting your video…',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_exportMessage(widget.progress),
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          if (widget.onCancel != null) ...[
            const SizedBox(height: 16),
            TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.accent4))),
          ],
        ]),
      );

  String _exportMessage(double p) {
    if (p < 0.2) return 'Preparing frames…';
    if (p < 0.5) return 'Encoding video…';
    if (p < 0.8) return 'Adding audio…';
    if (p < 0.95) return 'Finalizing…';
    return 'Almost done…';
  }
}

// ── Empty states (all variations) ─────────────────────────────────────────────

class EmptyProjects extends StatelessWidget {
  final VoidCallback onCreate;
  const EmptyProjects({super.key, required this.onCreate});
  @override
  Widget build(BuildContext ctx) => _EmptyView(
        emoji: '🎬',
        title: 'Create Your First Video',
        subtitle: 'Start from scratch or pick a template to get started',
        primaryLabel: '+ New Project',
        onPrimary: onCreate,
        secondaryLabel: 'Browse Templates',
        onSecondary: () => Navigator.pushNamed(ctx, '/templates'),
      );
}

class EmptyTemplates extends StatelessWidget {
  const EmptyTemplates({super.key});
  @override
  Widget build(BuildContext ctx) => _EmptyView(
        emoji: '🎨',
        title: 'No Templates Found',
        subtitle: 'Try a different search or category',
        primaryLabel: 'Clear Filters',
        onPrimary: () => Navigator.pop(ctx),
      );
}

class EmptyFavorites extends StatelessWidget {
  const EmptyFavorites({super.key});
  @override
  Widget build(BuildContext ctx) => _EmptyView(
        emoji: '❤️',
        title: 'No Saved Templates',
        subtitle: 'Tap the heart icon on any template to save it here',
        primaryLabel: 'Explore Templates',
        onPrimary: () => Navigator.pushNamed(ctx, '/templates'),
      );
}

class EmptySearch extends StatelessWidget {
  final String query;
  const EmptySearch({super.key, required this.query});
  @override
  Widget build(BuildContext ctx) => _EmptyView(
        emoji: '🔍',
        title: 'No Results for "$query"',
        subtitle: 'Try different keywords or browse templates instead',
        primaryLabel: 'Browse Templates',
        onPrimary: () => Navigator.pushNamed(ctx, '/templates'),
      );
}

class EmptyExportHistory extends StatelessWidget {
  const EmptyExportHistory({super.key});
  @override
  Widget build(BuildContext ctx) => const _EmptyView(
        emoji: '📤',
        title: 'No Exports Yet',
        subtitle: 'Your exported videos will appear here',
      );
}

class EmptyNotifications extends StatelessWidget {
  const EmptyNotifications({super.key});
  @override
  Widget build(BuildContext ctx) => const _EmptyView(
        emoji: '🔔',
        title: 'No Notifications',
        subtitle:
            "We'll notify you about new templates,\nexport completions, and special offers",
      );
}

class NetworkError extends StatelessWidget {
  final VoidCallback? onRetry;
  const NetworkError({super.key, this.onRetry});
  @override
  Widget build(BuildContext ctx) => _EmptyView(
        emoji: '📡',
        title: 'No Internet Connection',
        subtitle: 'Please check your connection and try again',
        primaryLabel: 'Try Again',
        onPrimary: onRetry,
      );
}

class ExportError extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;
  const ExportError({super.key, this.error, this.onRetry});
  @override
  Widget build(BuildContext ctx) => _EmptyView(
        emoji: '❌',
        title: 'Export Failed',
        subtitle: error ?? 'Something went wrong. Please try again.',
        primaryLabel: 'Retry Export',
        onPrimary: onRetry,
      );
}

// ── Generic empty view ─────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String emoji, title, subtitle;
  final String? primaryLabel, secondaryLabel;
  final VoidCallback? onPrimary, onSecondary;

  const _EmptyView({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
            if (primaryLabel != null && onPrimary != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.accent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(secondaryLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  )),
            ],
          ]),
        ),
      );
}

// lib/features/export/export_history_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../app_theme.dart';
import '../../core/utils/utils.dart';

class ExportJob {
  final String id, projectTitle, quality, status;
  final String? outputUrl;
  final double? progress;
  final DateTime createdAt;
  const ExportJob(
      {required this.id,
      required this.projectTitle,
      required this.quality,
      required this.status,
      this.outputUrl,
      this.progress,
      required this.createdAt});
}

class ExportHistoryScreen extends StatefulWidget {
  const ExportHistoryScreen({super.key});
  @override
  State<ExportHistoryScreen> createState() => _ExportHistoryScreenState();
}

class _ExportHistoryScreenState extends State<ExportHistoryScreen> {
  bool _loading = false;

  static final _sampleJobs = [
    ExportJob(
        id: '1',
        projectTitle: 'Summer Vlog 2024',
        quality: '1080p',
        status: 'done',
        outputUrl: '/storage/export1.mp4',
        createdAt: DateTime.now().subtract(const Duration(hours: 1))),
    ExportJob(
        id: '2',
        projectTitle: 'Birthday Party',
        quality: '4K',
        status: 'processing',
        progress: 0.65,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5))),
    ExportJob(
        id: '3',
        projectTitle: 'Wedding Highlights',
        quality: '1080p',
        status: 'done',
        outputUrl: '/storage/export3.mp4',
        createdAt: DateTime.now().subtract(const Duration(days: 1))),
    ExportJob(
        id: '4',
        projectTitle: 'Old Project',
        quality: '720p',
        status: 'failed',
        createdAt: DateTime.now().subtract(const Duration(days: 3))),
  ];

  Color _statusColor(String s) {
    switch (s) {
      case 'done':
        return AppTheme.green;
      case 'processing':
        return AppTheme.accent;
      case 'failed':
        return AppTheme.accent4;
      default:
        return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'done':
        return '✅ Done';
      case 'processing':
        return '⏳ Processing';
      case 'queued':
        return '🕐 Queued';
      case 'failed':
        return '❌ Failed';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg2,
        title: const Text('Export History'),
      ),
      body: _sampleJobs.isEmpty
          ? const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Text('📤', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 16),
                  Text('No exports yet',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Exported videos will appear here',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 13)),
                ]))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _sampleJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final job = _sampleJobs[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppTheme.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(job.projectTitle,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(job.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _statusColor(job.status)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(_statusLabel(job.status),
                                style: TextStyle(
                                    color: _statusColor(job.status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          _Tag(label: job.quality),
                          const SizedBox(width: 8),
                          Text(formatRelativeTime(job.createdAt),
                              style: const TextStyle(
                                  color: AppTheme.textTertiary, fontSize: 12)),
                        ]),

                        // Progress bar
                        if (job.status == 'processing' &&
                            job.progress != null) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: job.progress,
                            backgroundColor: AppTheme.border,
                            valueColor:
                                const AlwaysStoppedAnimation(AppTheme.accent),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${((job.progress ?? 0) * 100).toInt()}% complete',
                              style: const TextStyle(
                                  color: AppTheme.textTertiary, fontSize: 11)),
                        ],

                        // Actions
                        if (job.status == 'done' && job.outputUrl != null) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: OutlinedButton.icon(
                              onPressed: () => Share.shareXFiles(
                                  [XFile(job.outputUrl!)],
                                  subject: job.projectTitle),
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                side: const BorderSide(color: AppTheme.accent),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            )),
                            const SizedBox(width: 8),
                            Expanded(
                                child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Saved to Gallery')),
                                );
                              },
                              icon:
                                  const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Save'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.green,
                                side: const BorderSide(color: AppTheme.green),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            )),
                          ]),
                        ],
                      ]),
                );
              },
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppTheme.bg3,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.border)),
        child: Text(label,
            style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

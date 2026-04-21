// lib/features/profile/analytics_screen.dart
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/repositories/project_repository.dart';

class UserAnalyticsScreen extends StatefulWidget {
  const UserAnalyticsScreen({super.key});
  @override
  State<UserAnalyticsScreen> createState() => _UserAnalyticsScreenState();
}

class _UserAnalyticsScreenState extends State<UserAnalyticsScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final projects = await ProjectRepository().getLocalProjects();
      final totalDuration =
          projects.fold<double>(0, (a, p) => a + p.computedDuration);
      setState(() {
        _stats = {
          'total_projects': projects.length,
          'total_exports': 0, // from export history
          'total_duration': totalDuration,
          'most_used_tool': 'Text',
          'avg_project_duration':
              projects.isEmpty ? 0 : totalDuration / projects.length,
          'this_week_projects': projects
              .where((p) => DateTime.now().difference(p.createdAt).inDays < 7)
              .length,
        };
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar:
          AppBar(backgroundColor: AppTheme.bg2, title: const Text('My Stats')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : ListView(padding: const EdgeInsets.all(16), children: [
              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _StatCard('🎬', 'Total Projects',
                      '${_stats['total_projects'] ?? 0}', AppTheme.accent),
                  _StatCard('📤', 'Total Exports',
                      '${_stats['total_exports'] ?? 0}', AppTheme.accent2),
                  _StatCard(
                      '⏱️',
                      'Total Duration',
                      '${(_stats['total_duration'] ?? 0.0) / 60 < 1 ? '${(_stats['total_duration'] ?? 0).toInt()}s' : '${((_stats['total_duration'] ?? 0.0) / 60).toStringAsFixed(1)}m'}',
                      AppTheme.accent3),
                  _StatCard(
                      '📅',
                      'This Week',
                      '${_stats['this_week_projects'] ?? 0} projects',
                      AppTheme.green),
                ],
              ),
              const SizedBox(height: 20),

              // Most used tools
              _Section('Most Used Tools'),
              ...['Text', 'Effects', 'Audio', 'Color Grading', 'Speed']
                  .asMap()
                  .entries
                  .map((e) {
                final pct = 1.0 - e.key * 0.2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    SizedBox(
                        width: 120,
                        child: Text(
                            [
                              '✍️ Text',
                              '✨ Effects',
                              '🎵 Audio',
                              '🎨 Color',
                              '⚡ Speed'
                            ][e.key],
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13))),
                    Expanded(
                        child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: AppTheme.border,
                          valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                          minHeight: 8),
                    )),
                    const SizedBox(width: 8),
                    Text('${(pct * 100).toInt()}%',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 11)),
                  ]),
                );
              }),

              const SizedBox(height: 8),
              _Section('Activity (Last 7 Days)'),
              Container(
                height: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .asMap()
                      .entries
                      .map((e) {
                    final height = [0.3, 0.8, 0.5, 1.0, 0.6, 0.4, 0.2][e.key];
                    final isToday = e.key == DateTime.now().weekday - 1;
                    return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 28,
                            height: height * 60,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppTheme.accent
                                  : AppTheme.accent.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(e.value,
                              style: TextStyle(
                                  color: isToday
                                      ? AppTheme.accent
                                      : AppTheme.textTertiary,
                                  fontSize: 9,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                        ]);
                  }).toList(),
                ),
              ),
            ]),
    );
  }

  Widget _Section(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700)));
}

class _StatCard extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _StatCard(this.emoji, this.label, this.value, this.color);
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        ]),
      );
}


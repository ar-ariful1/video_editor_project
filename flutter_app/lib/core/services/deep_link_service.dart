// lib/core/services/deep_link_service.dart
// Deep link handling + last project resume + export status restore
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import '../../app_theme.dart';

class DeepLinkService {
  static final DeepLinkService _i = DeepLinkService._();
  factory DeepLinkService() => _i;
  DeepLinkService._();

  StreamSubscription? _sub;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;  // Add this

  Future<void> init() async {
    _appLinks = AppLinks();  // Initialize here
    
    // Handle cold start deep link
    try {
      final initial = await _appLinks.getInitialLink();  // Changed
      if (initial != null) {
        _handleLink(initial.toString());
      }
    } catch (_) {}

    // Handle warm start deep links
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {  // Changed
      if (uri != null) {
        _handleLink(uri.toString());
      }
    }, onError: (_) {});
  }

  void dispose() => _sub?.cancel();

  void _handleLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      return;
    }

    // videoeditorpro://editor?projectId=xxx
    if (uri.host == 'editor') {
      final projectId = uri.queryParameters['projectId'];
      navigatorKey.currentState
          ?.pushNamed('/editor', arguments: {'projectId': projectId});
    }
    // videoeditorpro://templates
    else if (uri.host == 'templates') {
      navigatorKey.currentState?.pushNamed('/templates');
    }
    // videoeditorpro://export?jobId=xxx
    else if (uri.host == 'export') {
      navigatorKey.currentState?.pushNamed('/exports');
    }
    // videoeditorpro://subscription
    else if (uri.host == 'subscription') {
      navigatorKey.currentState?.pushNamed('/subscription');
    }
  }

  // ── Last project resume ──────────────────────────────────────────────────────

  static const _lastProjectKey = 'last_opened_project_id';
  static const _lastProjectNameKey = 'last_opened_project_name';

  Future<void> saveLastProject(String projectId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastProjectKey, projectId);
    await prefs.setString(_lastProjectNameKey, name);
    await prefs.setInt(
        'last_project_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<Map<String, String>?> getLastProject() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_lastProjectKey);
    final name = prefs.getString(_lastProjectNameKey);
    final time = prefs.getInt('last_project_time') ?? 0;
    if (id == null || name == null) {
      return null;
    }
    // Only resume if last opened within 7 days
    if (DateTime.now().millisecondsSinceEpoch - time > 7 * 24 * 60 * 60 * 1000) {
      return null;
    }
    return {'id': id, 'name': name};
  }

  Future<void> clearLastProject() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastProjectKey);
    await prefs.remove(_lastProjectNameKey);
  }

  // ── Export status restore ────────────────────────────────────────────────────

  static const _activeExportKey = 'active_export_job_id';

  Future<void> saveActiveExport(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeExportKey, jobId);
  }

  Future<String?> getActiveExport() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeExportKey);
  }

  Future<void> clearActiveExport() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeExportKey);
  }
}

// ── Resume banner widget ──────────────────────────────────────────────────────

class ResumeBanner extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onDismiss;
  final String projectName;

  const ResumeBanner(
      {super.key,
      required this.onResume,
      required this.onDismiss,
      required this.projectName});

  @override
  State<ResumeBanner> createState() => _ResumeBannerState();
}

class _ResumeBannerState extends State<ResumeBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _anim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _dismiss() {
    _c.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _anim,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.accent.withValues(alpha: 0.9),
              AppTheme.accent2.withValues(alpha: 0.9)
            ]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(children: [
            const Text('✏️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Continue Editing',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text(widget.projectName,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            TextButton(
              onPressed: widget.onResume,
              style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Resume',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
                onTap: _dismiss,
                child: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18)),
          ]),
        ),
      );
}
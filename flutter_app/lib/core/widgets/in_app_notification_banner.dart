// lib/core/widgets/in_app_notification_banner.dart
// Animated in-app notification banner — shows on top of all content

import 'dart:async';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

enum NotifType { success, error, info, warning, export }

class NotifPayload {
  final String title, subtitle;
  final NotifType type;
  final VoidCallback? onTap;
  final Duration duration;

  const NotifPayload({
    required this.title,
    this.subtitle = '',
    this.type = NotifType.info,
    this.onTap,
    this.duration = const Duration(seconds: 4),
  });
}

// ── Global notification queue ─────────────────────────────────────────────────

class InAppNotifService {
  static final InAppNotifService _i = InAppNotifService._();
  factory InAppNotifService() => _i;
  InAppNotifService._();

  final _controller = StreamController<NotifPayload>.broadcast();
  Stream<NotifPayload> get stream => _controller.stream;

  void show(NotifPayload payload) => _controller.add(payload);

  void success(String title, {String subtitle = '', VoidCallback? onTap}) =>
      show(NotifPayload(
          title: title,
          subtitle: subtitle,
          type: NotifType.success,
          onTap: onTap));

  void error(String title, {String subtitle = '', VoidCallback? onTap}) =>
      show(NotifPayload(
          title: title,
          subtitle: subtitle,
          type: NotifType.error,
          onTap: onTap));

  void info(String title, {String subtitle = '', VoidCallback? onTap}) =>
      show(NotifPayload(
          title: title,
          subtitle: subtitle,
          type: NotifType.info,
          onTap: onTap));

  void exportComplete(String projectName, VoidCallback onView) =>
      show(NotifPayload(
          title: '✅ Export Complete',
          subtitle: '$projectName is ready',
          type: NotifType.export,
          onTap: onView,
          duration: const Duration(seconds: 6)));

  void dispose() => _controller.close();
}

// ── Banner overlay (wrap around your root widget) ─────────────────────────────

class InAppNotifOverlay extends StatefulWidget {
  final Widget child;
  const InAppNotifOverlay({super.key, required this.child});
  @override
  State<InAppNotifOverlay> createState() => _InAppNotifOverlayState();
}

class _InAppNotifOverlayState extends State<InAppNotifOverlay> {
  final _queue = <NotifPayload>[];
  NotifPayload? _current;
  StreamSubscription? _sub;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _sub = InAppNotifService().stream.listen((payload) {
      _queue.add(payload);
      if (_current == null) _showNext();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _showNext() {
    if (_queue.isEmpty) {
      setState(() => _current = null);
      return;
    }
    setState(() => _current = _queue.removeAt(0));
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_current!.duration, _dismiss);
  }

  void _dismiss() {
    setState(() => _current = null);
    Future.delayed(const Duration(milliseconds: 400), _showNext);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_current != null)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: _Banner(payload: _current!, onDismiss: _dismiss),
        ),
    ]);
  }
}

// ── Banner widget ─────────────────────────────────────────────────────────────

class _Banner extends StatefulWidget {
  final NotifPayload payload;
  final VoidCallback onDismiss;
  const _Banner({required this.payload, required this.onDismiss});
  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg {
    switch (widget.payload.type) {
      case NotifType.success:
      case NotifType.export:
        return AppTheme.green.withValues(alpha: 0.95);
      case NotifType.error:
        return AppTheme.accent4.withValues(alpha: 0.95);
      case NotifType.warning:
        return AppTheme.accent3.withValues(alpha: 0.95);
      default:
        return AppTheme.bg2.withValues(alpha: 0.97);
    }
  }

  String get _icon {
    switch (widget.payload.type) {
      case NotifType.success:
        return '✅';
      case NotifType.export:
        return '🎬';
      case NotifType.error:
        return '❌';
      case NotifType.warning:
        return '⚠️';
      default:
        return 'ℹ️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            onTap: () {
              widget.payload.onTap?.call();
              widget.onDismiss();
            },
            onVerticalDragEnd: (d) {
              if (d.velocity.pixelsPerSecond.dy < -200) widget.onDismiss();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Row(children: [
                Text(_icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.payload.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      if (widget.payload.subtitle.isNotEmpty)
                        Text(widget.payload.subtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                    ])),
                if (widget.payload.onTap != null)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('View',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 16)),
              ]),
            ),
          ),
        ));
  }
}


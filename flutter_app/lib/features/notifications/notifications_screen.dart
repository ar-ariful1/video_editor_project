// lib/features/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../app_theme.dart';
import '../../core/utils/utils.dart';

// ── Notification Service ──────────────────────────────────────────────────────
class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _fcm = FirebaseMessaging.instance;

  Future<void> init(String userId) async {
    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    // Get FCM token and send to backend
    final token = await _fcm.getToken();
    if (token != null) await _registerToken(token, userId);

    // Token refresh
    _fcm.onTokenRefresh.listen((t) => _registerToken(t, userId));

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Background tap (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App launched from terminated via notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  Future<void> _registerToken(String token, String userId) async {
    // POST to backend /users/{userId}/fcm-token
    // TODO: implement with Dio service
  }

  void _handleForeground(RemoteMessage msg) {
    // Show in-app notification banner
    NotificationStore.instance.add(_toModel(msg));
  }

  void _handleTap(RemoteMessage msg) {
    final data = msg.data;
    // Deep link routing based on data['type']
    switch (data['type']) {
      case 'template_drop':
        /* navigate to templates */ break;
      case 'export_complete':
        /* navigate to export history */ break;
      case 'subscription_expiry':
        /* navigate to subscription */ break;
    }
  }

  NotificationModel _toModel(RemoteMessage msg) => NotificationModel(
        id: msg.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: msg.notification?.title ?? '',
        body: msg.notification?.body ?? '',
        type: msg.data['type'] ?? 'general',
        data: Map<String, String>.from(msg.data),
        receivedAt: DateTime.now(),
        isRead: false,
      );
}

// ── Notification Store (in-memory) ────────────────────────────────────────────
class NotificationStore extends ChangeNotifier {
  static final NotificationStore instance = NotificationStore._();
  NotificationStore._();

  final List<NotificationModel> _notifications = [];
  List<NotificationModel> get all => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void add(NotificationModel n) {
    _notifications.insert(0, n);
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    notifyListeners();
  }
}

class NotificationModel {
  final String id, title, body, type;
  final Map<String, String> data;
  final DateTime receivedAt;
  final bool isRead;

  const NotificationModel(
      {required this.id,
      required this.title,
      required this.body,
      required this.type,
      required this.data,
      required this.receivedAt,
      required this.isRead});

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      data: data,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead);
}

// ── Notifications Screen ──────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationStore.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    NotificationStore.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  static final _sampleNotifications = [
    NotificationModel(
        id: '1',
        title: '🎨 New Templates Drop!',
        body: '15 new wedding templates just added to the marketplace.',
        type: 'template_drop',
        data: {},
        receivedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false),
    NotificationModel(
        id: '2',
        title: '✅ Export Complete',
        body: 'Your video "Summer Vlog" has been exported successfully.',
        type: 'export_complete',
        data: {'project_id': 'abc'},
        receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false),
    NotificationModel(
        id: '3',
        title: '👑 Upgrade to Premium',
        body: 'Unlock 4K export, unlimited AI, and all templates.',
        type: 'promo',
        data: {},
        receivedAt: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true),
    NotificationModel(
        id: '4',
        title: '🤖 AI Caption Ready',
        body: 'Your auto-captions are ready in "Birthday Party 2024".',
        type: 'ai_done',
        data: {},
        receivedAt: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true),
  ];

  @override
  Widget build(BuildContext context) {
    final store = NotificationStore.instance;
    final items = store.all.isEmpty ? _sampleNotifications : store.all;
    final unread = items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg2,
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: store.markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(color: AppTheme.accent, fontSize: 12)),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const Text('🔔', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  const Text('No notifications yet',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text(
                      "We'll notify you about new templates\nand feature updates",
                      style:
                          TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                      textAlign: TextAlign.center),
                ]))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.border, indent: 68),
              itemBuilder: (_, i) => _NotifTile(
                notif: items[i],
                onTap: () => store.markRead(items[i].id),
              ),
            ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  String _typeIcon(String type) {
    switch (type) {
      case 'template_drop':
        return '🎨';
      case 'export_complete':
        return '✅';
      case 'ai_done':
        return '🤖';
      case 'subscription_expiry':
        return '⚠️';
      case 'promo':
        return '👑';
      default:
        return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: notif.isRead
            ? Colors.transparent
            : AppTheme.accent.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.bg3,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
                child: Text(_typeIcon(notif.type),
                    style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(notif.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ))),
                  if (!notif.isRead)
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: AppTheme.accent, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 3),
                Text(notif.body,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(formatRelativeTime(notif.receivedAt),
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11)),
              ])),
        ]),
      ),
    );
  }
}


// lib/core/services/remote_config_service.dart
// Remote config + auto update + force update — silent feature changes

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Remote config model ───────────────────────────────────────────────────────

class RemoteConfig {
  // Feature flags
  final bool aiEnabled;
  final bool proxyEditingEnabled;
  final bool chromaKeyEnabled;
  final bool export4kEnabled;
  final bool templateAutoplay;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  // Limits
  final int freeProjectLimit;
  final int freeAiMinutesPerDay;
  final int maxExportQueueSize;

  // UI config
  final String paywallHeadline;
  final double proMonthlyPrice;
  final double premiumMonthlyPrice;

  // Update config
  final String minSupportedVersion;
  final String currentVersion;
  final bool forceUpdate;
  final String? updateUrl;
  final String? updateMessage;

  // Content
  final List<String> featuredTemplateIds;
  final List<String> trendingHashtags;

  const RemoteConfig({
    this.aiEnabled = true,
    this.proxyEditingEnabled = true,
    this.chromaKeyEnabled = true,
    this.export4kEnabled = true,
    this.templateAutoplay = true,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.freeProjectLimit = 3,
    this.freeAiMinutesPerDay = 0,
    this.maxExportQueueSize = 5,
    this.paywallHeadline = '✨ Upgrade to Pro',
    this.proMonthlyPrice = 4.99,
    this.premiumMonthlyPrice = 9.99,
    this.minSupportedVersion = '1.0.0',
    this.currentVersion = '1.0.0',
    this.forceUpdate = false,
    this.updateUrl,
    this.updateMessage,
    this.featuredTemplateIds = const [],
    this.trendingHashtags = const [],
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> j) => RemoteConfig(
        aiEnabled: j['ai_enabled'] ?? true,
        proxyEditingEnabled: j['proxy_editing_enabled'] ?? true,
        chromaKeyEnabled: j['chroma_key_enabled'] ?? true,
        export4kEnabled: j['export_4k_enabled'] ?? true,
        templateAutoplay: j['template_autoplay'] ?? true,
        maintenanceMode: j['maintenance_mode'] ?? false,
        maintenanceMessage: j['maintenance_message'],
        freeProjectLimit: j['free_project_limit'] ?? 3,
        freeAiMinutesPerDay: j['free_ai_minutes_per_day'] ?? 0,
        maxExportQueueSize: j['max_export_queue_size'] ?? 5,
        paywallHeadline: j['paywall_headline'] ?? '✨ Upgrade to Pro',
        proMonthlyPrice: (j['pro_monthly_price'] as num?)?.toDouble() ?? 4.99,
        premiumMonthlyPrice:
            (j['premium_monthly_price'] as num?)?.toDouble() ?? 9.99,
        minSupportedVersion: j['min_supported_version'] ?? '1.0.0',
        currentVersion: j['current_version'] ?? '1.0.0',
        forceUpdate: j['force_update'] ?? false,
        updateUrl: j['update_url'],
        updateMessage: j['update_message'],
        featuredTemplateIds:
            List<String>.from(j['featured_template_ids'] ?? []),
        trendingHashtags: List<String>.from(j['trending_hashtags'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'ai_enabled': aiEnabled,
        'proxy_editing_enabled': proxyEditingEnabled,
        'chroma_key_enabled': chromaKeyEnabled,
        'export_4k_enabled': export4kEnabled,
        'template_autoplay': templateAutoplay,
        'maintenance_mode': maintenanceMode,
        'maintenance_message': maintenanceMessage,
        'free_project_limit': freeProjectLimit,
        'free_ai_minutes_per_day': freeAiMinutesPerDay,
        'max_export_queue_size': maxExportQueueSize,
        'paywall_headline': paywallHeadline,
        'pro_monthly_price': proMonthlyPrice,
        'premium_monthly_price': premiumMonthlyPrice,
        'min_supported_version': minSupportedVersion,
        'current_version': currentVersion,
        'force_update': forceUpdate,
        'update_url': updateUrl,
        'update_message': updateMessage,
        'featured_template_ids': featuredTemplateIds,
        'trending_hashtags': trendingHashtags,
      };
}

// ── Remote config service ─────────────────────────────────────────────────────

class RemoteConfigService extends ChangeNotifier {
  static final RemoteConfigService _i = RemoteConfigService._();
  factory RemoteConfigService() => _i;
  RemoteConfigService._();

  static const _apiBase = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.videoeditorpro.app');
  static const _appVersion = '1.0.0';
  static const _cacheKey = 'remote_config';
  static const _cacheTTL = Duration(hours: 1);

  final _dio = Dio();
  RemoteConfig _config = const RemoteConfig();
  DateTime? _lastFetch;

  RemoteConfig get config => _config;

  // ── Init & fetch ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadCache();
    await fetch(); // Always try fresh fetch
  }

  Future<void> fetch({bool force = false}) async {
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTTL) {
      return;
    }

    try {
      final res = await _dio.get(
        '$_apiBase/config',
        queryParameters: {'version': _appVersion, 'platform': 'flutter'},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      if (res.statusCode == 200) {
        final newConfig =
            RemoteConfig.fromJson(res.data as Map<String, dynamic>);
        _config = newConfig;
        _lastFetch = DateTime.now();
        await _saveCache(newConfig);
        notifyListeners();
      }
    } catch (_) {
      // Use cached config silently
    }
  }

  // ── Force update check ─────────────────────────────────────────────────────────

  bool get needsForceUpdate {
    if (!_config.forceUpdate) return false;
    return _compareVersions(_appVersion, _config.minSupportedVersion) < 0;
  }

  Future<void> showForceUpdateDialog(BuildContext context) async {
    if (!needsForceUpdate) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          _config.updateMessage ??
              'A critical update is available. Please update to continue.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final url =
                  _config.updateUrl ?? 'https://videoeditorpro.app/update';
              if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
            },
            child: const Text('Update Now',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Maintenance mode ──────────────────────────────────────────────────────────

  bool get isInMaintenance => _config.maintenanceMode;

  // ── Cache ─────────────────────────────────────────────────────────────────────

  Future<void> _saveCache(RemoteConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
    await prefs.setString('${_cacheKey}_ts', DateTime.now().toIso8601String());
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final ts = prefs.getString('${_cacheKey}_ts');
      if (raw == null) {
        return;
      }
      _config = RemoteConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _lastFetch = ts != null ? DateTime.tryParse(ts) : null;
    } catch (_) {}
  }

  // ── Semver comparison ─────────────────────────────────────────────────────────

  int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.parse).toList();
    final pb = b.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) {
        return va.compareTo(vb);
      }
    }
    return 0;
  }
}

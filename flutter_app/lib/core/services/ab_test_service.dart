// lib/core/services/ab_test_service.dart
// Client-side A/B testing — paywall variants, CTA tests, UI experiments
// Integrates with admin panel A/B test management

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

// ── Test definitions ──────────────────────────────────────────────────────────

class ABTest {
  final String name;
  final List<String> variants;
  final Map<String, int> weights; // variant → weight (0–100)

  const ABTest(
      {required this.name, required this.variants, required this.weights});

  // Assign variant based on user hash
  String assignVariant(String userId) {
    final hash = userId.codeUnits.fold(0, (a, b) => a * 31 + b) % 100;
    int cumulative = 0;
    for (final v in variants) {
      cumulative += weights[v] ?? (100 ~/ variants.length);
      if (hash < cumulative) return v;
    }
    return variants.last;
  }
}

// ── Current active tests ──────────────────────────────────────────────────────

class ActiveTests {
  // Paywall test — different pricing copy
  static const paywall = ABTest(
    name: 'paywall_v2',
    variants: ['control', 'urgency', 'social_proof'],
    weights: {'control': 34, 'urgency': 33, 'social_proof': 33},
  );

  // Export CTA button text
  static const exportCta = ABTest(
    name: 'export_cta',
    variants: ['Export', 'Save Video', 'Export Now'],
    weights: {'Export': 34, 'Save Video': 33, 'Export Now': 33},
  );

  // Home screen layout
  static const homeLayout = ABTest(
    name: 'home_layout',
    variants: ['grid', 'list', 'cards'],
    weights: {'grid': 60, 'list': 20, 'cards': 20},
  );

  // Onboarding flow
  static const onboarding = ABTest(
    name: 'onboarding_v3',
    variants: ['skip_friendly', 'feature_first', 'video_demo'],
    weights: {'skip_friendly': 40, 'feature_first': 40, 'video_demo': 20},
  );
}

// ── A/B test service ──────────────────────────────────────────────────────────

class ABTestService {
  static final ABTestService _i = ABTestService._();
  factory ABTestService() => _i;
  ABTestService._();

  final _dio = Dio();
  final _cache = <String, String>{}; // testName → assigned variant
  final _converted = <String, bool>{}; // testName → converted
  String? _userId;

  static const _apiBase = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.videoeditorpro.app');

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    _userId = userId;
    await _loadFromPrefs();
    await _syncFromBackend();
  }

  // ── Get variant ───────────────────────────────────────────────────────────────

  String getVariant(ABTest test) {
    final cached = _cache[test.name];
    if (cached != null) return cached;

    // Deterministically assign from userId hash
    final userId = _userId ?? 'anonymous';
    final variant = test.assignVariant(userId);
    _cache[test.name] = variant;
    _persistToPrefs();
    _reportAssignment(test.name, variant);
    return variant;
  }

  // Typed convenience methods
  String get paywallVariant => getVariant(ActiveTests.paywall);
  String get exportCtaText => getVariant(ActiveTests.exportCta);
  String get homeLayoutMode => getVariant(ActiveTests.homeLayout);
  String get onboardingFlow => getVariant(ActiveTests.onboarding);

  bool isVariant(ABTest test, String variant) => getVariant(test) == variant;

  // ── Record conversion ─────────────────────────────────────────────────────────

  Future<void> recordConversion(ABTest test,
      {Map<String, dynamic>? properties}) async {
    final variant = _cache[test.name];
    if (variant == null || _converted[test.name] == true) return;

    _converted[test.name] = true;
    await _reportConversion(test.name, variant, properties);
  }

  // Typed conversions
  Future<void> paywallConverted({required String plan}) =>
      recordConversion(ActiveTests.paywall, properties: {'plan': plan});

  Future<void> exportCtaClicked() => recordConversion(ActiveTests.exportCta);

  // ── Paywall copy by variant ───────────────────────────────────────────────────

  Map<String, String> get paywallCopy {
    switch (paywallVariant) {
      case 'urgency':
        return {
          'headline': '🔥 Limited Time — 50% Off Pro',
          'subtext': 'Offer expires in 24 hours. No watermark, 1080p exports.',
          'cta': 'Claim Discount Now',
        };
      case 'social_proof':
        return {
          'headline': '⭐ Join 2M+ Creators on Pro',
          'subtext': 'Professional results. Trusted by creators worldwide.',
          'cta': 'Start Creating Now',
        };
      default: // control
        return {
          'headline': '✨ Upgrade to Pro',
          'subtext': 'Remove watermark, export in 1080p, unlock all features.',
          'cta': 'Upgrade to Pro',
        };
    }
  }

  // ── Backend sync ──────────────────────────────────────────────────────────────

  Future<void> _syncFromBackend() async {
    if (_userId == null) return;
    try {
      final res = await _dio.get(
        '$_apiBase/ab-tests/assignments',
        queryParameters: {'userId': _userId},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final data = res.data as Map<String, dynamic>?;
      if (data?['assignments'] is Map) {
        final assignments = data!['assignments'] as Map<String, dynamic>;
        assignments
            .forEach((test, variant) => _cache[test] = variant.toString());
        await _persistToPrefs();
      }
    } catch (_) {} // Use local cache if backend unavailable
  }

  Future<void> _reportAssignment(String testName, String variant) async {
    if (_userId == null) return;
    try {
      await _dio.post(
        '$_apiBase/ab-tests/assignment',
        data: {'userId': _userId, 'test': testName, 'variant': variant},
        options: Options(sendTimeout: const Duration(seconds: 3)),
      );
    } catch (_) {}
  }

  Future<void> _reportConversion(
      String testName, String variant, Map<String, dynamic>? props) async {
    if (_userId == null) return;
    try {
      await _dio.post(
        '$_apiBase/ab-tests/conversion',
        data: {
          'userId': _userId,
          'test': testName,
          'variant': variant,
          'properties': props
        },
        options: Options(sendTimeout: const Duration(seconds: 3)),
      );
    } catch (_) {}
  }

  // ── Persistence ───────────────────────────────────────────────────────────────

  Future<void> _persistToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ab_assignments', jsonEncode(_cache));
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ab_assignments');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) => _cache[k] = v.toString());
      }
    } catch (_) {}
  }

  void clear() {
    _cache.clear();
    _converted.clear();
  }
}

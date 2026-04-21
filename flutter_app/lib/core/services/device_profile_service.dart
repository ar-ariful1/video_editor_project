// lib/core/services/device_profile_service.dart
// Device profiling + Lite Mode — optimized for low-RAM devices (Bangladesh/India market)

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

// ── Device tiers ──────────────────────────────────────────────────────────────

enum DeviceTier {
  flagship, // >6GB RAM, modern GPU — full features
  midRange, // 4-6GB RAM — all features, balanced perf
  budget, // 2-4GB RAM — lite mode recommended
  lowEnd, // <2GB RAM — lite mode enforced
}

extension DeviceTierExt on DeviceTier {
  bool get shouldUseLiteMode => index >= DeviceTier.budget.index;
  bool get isLowEnd => index == DeviceTier.lowEnd.index;
  String get label => ['Flagship', 'Mid-Range', 'Budget', 'Low-End'][index];
}

// ── Lite Mode config ──────────────────────────────────────────────────────────

class LiteModeConfig {
  final bool enabled;
  final int previewFps;
  final int previewWidth;
  final bool forceProxy;
  final bool disableHeavyEffects;
  final bool disableRealtime3D;
  final int maxTracks;
  final int maxClipsPerTrack;
  final bool disableWaveform;
  final bool disableColorScopes;
  final int maxUndoSteps;
  final int thumbCacheMB;
  final int videoCacheMB;

  const LiteModeConfig({
    required this.enabled,
    required this.previewFps,
    required this.previewWidth,
    required this.forceProxy,
    required this.disableHeavyEffects,
    required this.disableRealtime3D,
    required this.maxTracks,
    required this.maxClipsPerTrack,
    required this.disableWaveform,
    required this.disableColorScopes,
    required this.maxUndoSteps,
    required this.thumbCacheMB,
    required this.videoCacheMB,
  });

  factory LiteModeConfig.full() => const LiteModeConfig(
        enabled: false,
        previewFps: 60,
        previewWidth: 1080,
        forceProxy: false,
        disableHeavyEffects: false,
        disableRealtime3D: false,
        maxTracks: 20,
        maxClipsPerTrack: 100,
        disableWaveform: false,
        disableColorScopes: false,
        maxUndoSteps: 50,
        thumbCacheMB: 64,
        videoCacheMB: 512,
      );

  factory LiteModeConfig.balanced() => const LiteModeConfig(
        enabled: true,
        previewFps: 30,
        previewWidth: 720,
        forceProxy: true,
        disableHeavyEffects: false,
        disableRealtime3D: false,
        maxTracks: 10,
        maxClipsPerTrack: 50,
        disableWaveform: false,
        disableColorScopes: true,
        maxUndoSteps: 30,
        thumbCacheMB: 32,
        videoCacheMB: 256,
      );

  factory LiteModeConfig.lite() => const LiteModeConfig(
        enabled: true,
        previewFps: 24,
        previewWidth: 480,
        forceProxy: true,
        disableHeavyEffects: true,
        disableRealtime3D: true,
        maxTracks: 5,
        maxClipsPerTrack: 20,
        disableWaveform: true,
        disableColorScopes: true,
        maxUndoSteps: 15,
        thumbCacheMB: 16,
        videoCacheMB: 128,
      );

  factory LiteModeConfig.ultraLite() => const LiteModeConfig(
        enabled: true,
        previewFps: 15,
        previewWidth: 360,
        forceProxy: true,
        disableHeavyEffects: true,
        disableRealtime3D: true,
        maxTracks: 3,
        maxClipsPerTrack: 10,
        disableWaveform: true,
        disableColorScopes: true,
        maxUndoSteps: 10,
        thumbCacheMB: 8,
        videoCacheMB: 64,
      );
}

// ── Device profile service ────────────────────────────────────────────────────

class DeviceProfileService {
  static final DeviceProfileService _i = DeviceProfileService._();
  factory DeviceProfileService() => _i;
  DeviceProfileService._();

  static const _channel =
      MethodChannel('com.clipcut.app/engine');

  DeviceTier _tier = DeviceTier.midRange;
  LiteModeConfig _config = LiteModeConfig.full();
  bool _userOverride = false; // user manually set mode
  int _ramMB = 4096;
  int _cpuCores = 4;
  String _gpuModel = 'Unknown';

  DeviceTier get tier => _tier;
  LiteModeConfig get config => _config;
  bool get isLite => _config.enabled;
  int get ramMB => _ramMB;

  // ── Init & detect ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _detectDevice();
    await _loadUserPreference();

    if (!_userOverride) {
      _config = _configForTier(_tier);
    }

    debugPrint(
        '📱 Device: ${_tier.label} — ${_ramMB}MB RAM — Lite: ${_config.enabled}');
  }

  Future<void> _detectDevice() async {
    try {
      final info = await _channel.invokeMethod<Map>('getDeviceInfo');
      if (info != null) {
        _ramMB = info['ramMB'] as int? ?? 4096;
        _cpuCores = info['cpuCores'] as int? ?? 4;
        _gpuModel = info['gpu'] as String? ?? 'Unknown';
      }
    } catch (_) {
      // Fallback: estimate from platform
      if (Platform.isAndroid) _ramMB = 3072;
      if (Platform.isIOS) _ramMB = 4096;
    }

    // Classify tier
    if (_ramMB >= 8192) {
      _tier = DeviceTier.flagship;
    } else if (_ramMB >= 4096) {
      _tier = DeviceTier.midRange;
    } else if (_ramMB >= 2048) {
      _tier = DeviceTier.budget;
    } else {
      _tier = DeviceTier.lowEnd;
    }
  }

  LiteModeConfig _configForTier(DeviceTier t) {
    switch (t) {
      case DeviceTier.flagship:
        return LiteModeConfig.full();
      case DeviceTier.midRange:
        return LiteModeConfig.full();
      case DeviceTier.budget:
        return LiteModeConfig.balanced();
      case DeviceTier.lowEnd:
        return LiteModeConfig.ultraLite();
    }
  }

  // ── User can override ─────────────────────────────────────────────────────────

  Future<void> setLiteMode(bool enabled) async {
    _userOverride = true;
    _config = enabled ? LiteModeConfig.lite() : LiteModeConfig.full();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lite_mode_override', true);
    await prefs.setBool('lite_mode_enabled', enabled);
  }

  Future<void> _loadUserPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _userOverride = prefs.getBool('lite_mode_override') ?? false;
    if (_userOverride) {
      final enabled = prefs.getBool('lite_mode_enabled') ?? false;
      _config = enabled ? LiteModeConfig.lite() : LiteModeConfig.full();
    }
  }

  void resetToAuto() async {
    _userOverride = false;
    _config = _configForTier(_tier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lite_mode_override');
  }

  // ── Effect availability check ─────────────────────────────────────────────────

  bool canUseEffect(String effectType) {
    if (!_config.disableHeavyEffects) return true;
    const heavyEffects = {
      'blur',
      'grain',
      'vignette',
      'glitch',
      'fisheye',
      'halftone',
      'chromatic'
    };
    return !heavyEffects.contains(effectType);
  }

  bool canUseFeature(String feature) {
    switch (feature) {
      case 'waveform':
        return !_config.disableWaveform;
      case 'color_scopes':
        return !_config.disableColorScopes;
      case 'realtime_3d':
        return !_config.disableRealtime3D;
      case 'keyframe':
        return _tier.index <= DeviceTier.budget.index;
      default:
        return true;
    }
  }

  // ── Lite mode banner widget ───────────────────────────────────────────────────

  Map<String, dynamic> get statusInfo => {
        'tier': _tier.label,
        'ramMB': _ramMB,
        'cpuCores': _cpuCores,
        'gpu': _gpuModel,
        'liteMode': _config.enabled,
        'fps': _config.previewFps,
        'maxTracks': _config.maxTracks,
        'proxy': _config.forceProxy,
      };
}

// ── Lite mode banner ──────────────────────────────────────────────────────────

class LiteModeBanner extends StatelessWidget {
  const LiteModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = DeviceProfileService();
    if (!svc.isLite) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accent3.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent3.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lite Mode Active',
              style: TextStyle(
                  color: AppTheme.accent3,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          Text(
              '${svc.config.previewFps}fps preview · proxy editing · optimized for your device',
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
        ])),
        GestureDetector(
          onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: AppTheme.bg2,
              builder: (_) => _LiteModeSheet()),
          child: const Icon(Icons.info_outline_rounded,
              color: AppTheme.accent3, size: 16),
        ),
      ]),
    );
  }
}

class _LiteModeSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final svc = DeviceProfileService();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ Lite Mode',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
                'Your device has ${svc.ramMB}MB RAM (${svc.tier.label}). Lite Mode reduces features to keep the editor smooth.',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            _infoRow('Preview FPS', '${svc.config.previewFps}fps'),
            _infoRow('Preview Quality', '${svc.config.previewWidth}p'),
            _infoRow('Max Tracks', '${svc.config.maxTracks}'),
            _infoRow('Proxy Editing', svc.config.forceProxy ? '✅ Forced' : '❌'),
            _infoRow('Heavy Effects',
                svc.config.disableHeavyEffects ? '❌ Disabled' : '✅'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () {
                  svc.setLiteMode(false);
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Full Mode'),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep Lite'),
              )),
            ]),
          ]),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12))),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}


// lib/core/engine/performance_manager.dart
// GPU fallback, thermal throttling, battery saver — adaptive quality engine

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

// ── Performance modes ─────────────────────────────────────────────────────────

enum PerformanceMode { ultra, high, balanced, low, battery }

extension PerformanceModeExt on PerformanceMode {
  int get previewFps => [60, 30, 30, 24, 15][index];
  int get previewWidth => [1080, 1080, 720, 540, 360][index];
  int get frameBufferSize => [32, 16, 8, 4, 2][index];
  bool get useProxy => index >= 2; // balanced and below use proxy
  bool get useHardwareEnc => index <= 2; // ultra/high/balanced use HW
  int get audioBitrate => [320, 192, 128, 96, 64][index];
  String get label =>
      ['Ultra', 'High', 'Balanced', 'Low', 'Battery Saver'][index];
}

// ── Thermal state ─────────────────────────────────────────────────────────────

enum ThermalState { nominal, fair, serious, critical }

// ── Performance manager ───────────────────────────────────────────────────────

class PerformanceManager extends ChangeNotifier {
  static final PerformanceManager _i = PerformanceManager._();
  factory PerformanceManager() => _i;
  PerformanceManager._();

  static const _channel =
      MethodChannel('com.clipcut.app/performance');

  PerformanceMode _mode = PerformanceMode.balanced;
  ThermalState _thermal = ThermalState.nominal;
  bool _gpuAvailable = true;
  bool _batterySaverActive = false;
  bool _autoMode = true;

  Timer? _monitorTimer;
  final _modeCtrl = StreamController<PerformanceMode>.broadcast();
  final _thermalCtrl = StreamController<ThermalState>.broadcast();

  Stream<PerformanceMode> get modeStream => _modeCtrl.stream;
  Stream<ThermalState> get thermalStream => _thermalCtrl.stream;

  PerformanceMode get mode => _mode;
  ThermalState get thermal => _thermal;
  bool get gpuAvailable => _gpuAvailable;
  bool get isLowPower =>
      _mode == PerformanceMode.battery || _mode == PerformanceMode.low;

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadPrefs();
    await _checkGPU();
    _startMonitoring();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _autoMode = prefs.getBool('perf_auto_mode') ?? true;
    if (!_autoMode) {
      final modeIdx =
          prefs.getInt('perf_mode') ?? PerformanceMode.balanced.index;
      _mode = PerformanceMode
          .values[modeIdx.clamp(0, PerformanceMode.values.length - 1)];
    }
  }

  // ── GPU check ─────────────────────────────────────────────────────────────────

  Future<void> _checkGPU() async {
    try {
      final result = await _channel.invokeMethod<bool>('isGPUAvailable');
      _gpuAvailable = result ?? true;
    } catch (_) {
      _gpuAvailable = true; // assume available
    }
    if (!_gpuAvailable) {
      debugPrint('⚠️ GPU unavailable — falling back to CPU rendering');
      if (_autoMode) setMode(PerformanceMode.low);
    }
  }

  // ── Thermal monitoring ────────────────────────────────────────────────────────

  void _startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _pollThermal());
  }

  Future<void> _pollThermal() async {
    try {
      final level = await _channel.invokeMethod<int>('getThermalState') ?? 0;
      final newThermal = ThermalState.values[level.clamp(0, 3)];

      if (newThermal != _thermal) {
        _thermal = newThermal;
        _thermalCtrl.add(_thermal);

        if (_autoMode) _adaptToThermal(newThermal);
      }
    } catch (_) {}

    // Check battery saver
    try {
      final isBatterySaver =
          await _channel.invokeMethod<bool>('isBatterySaverActive') ?? false;
      if (isBatterySaver != _batterySaverActive) {
        _batterySaverActive = isBatterySaver;
        if (_autoMode && isBatterySaver) setMode(PerformanceMode.battery);
      }
    } catch (_) {}
  }

  void _adaptToThermal(ThermalState thermal) {
    switch (thermal) {
      case ThermalState.nominal:
        if (_mode.index > PerformanceMode.balanced.index) {
          setMode(PerformanceMode.balanced);
        }
        break;
      case ThermalState.fair:
        if (_mode.index < PerformanceMode.balanced.index) {
          setMode(PerformanceMode.balanced);
        }
        break;
      case ThermalState.serious:
        setMode(PerformanceMode.low);
        debugPrint('🌡️ Thermal serious — reducing to Low performance');
        break;
      case ThermalState.critical:
        setMode(PerformanceMode.battery);
        debugPrint('🔥 Thermal critical — battery saver mode');
        break;
    }
  }

  // ── Set mode ──────────────────────────────────────────────────────────────────

  Future<void> setMode(PerformanceMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    _modeCtrl.add(mode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('perf_mode', mode.index);

    // Apply to native engine
    try {
      await _channel.invokeMethod(
          'setPerformanceMode', {'mode': mode.index, 'fps': mode.previewFps});
    } catch (_) {}

    debugPrint(
        '⚡ Performance mode: ${mode.label} (${mode.previewFps}fps, proxy: ${mode.useProxy})');
  }

  void setAutoMode(bool auto) {
    _autoMode = auto;
    if (auto) _adaptToThermal(_thermal);
  }

  // ── GPU fallback ──────────────────────────────────────────────────────────────

  Future<bool> tryGPURender(Future<bool> Function() gpuTask) async {
    if (!_gpuAvailable) return false;
    try {
      return await gpuTask();
    } catch (e) {
      debugPrint('GPU render failed: $e — switching to CPU');
      _gpuAvailable = false;
      if (_autoMode) setMode(PerformanceMode.low);
      return false;
    }
  }

  // ── Frame budget advisor ──────────────────────────────────────────────────────

  /// Returns max time (ms) allowed for one frame render
  double get frameBudgetMs {
    switch (_mode) {
      case PerformanceMode.ultra:
        return 16.67; // 60fps budget
      case PerformanceMode.high:
        return 33.33; // 30fps
      case PerformanceMode.balanced:
        return 33.33;
      case PerformanceMode.low:
        return 41.67; // 24fps
      case PerformanceMode.battery:
        return 66.67; // 15fps
    }
  }

  bool isWithinBudget(double frameMs) => frameMs <= frameBudgetMs;

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _modeCtrl.close();
    _thermalCtrl.close();
    super.dispose();
  }
}

// ── Performance indicator widget ──────────────────────────────────────────────

class PerformanceBadge extends StatelessWidget {
  const PerformanceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PerformanceManager(),
      builder: (_, __) {
        final pm = PerformanceManager();
        final mode = pm.mode;
        final color = mode == PerformanceMode.battery
            ? AppTheme.accent3
            : mode == PerformanceMode.low
                ? AppTheme.accent
                : mode == PerformanceMode.ultra
                    ? AppTheme.green
                    : AppTheme.textTertiary;

        return Row(mainAxisSize: MainAxisSize.min, children: [
          if (pm.thermal == ThermalState.serious ||
              pm.thermal == ThermalState.critical)
            const Text('🌡️', style: TextStyle(fontSize: 12)),
          if (!pm.gpuAvailable)
            const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text('CPU',
                    style: TextStyle(
                        color: AppTheme.accent3,
                        fontSize: 9,
                        fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text('${mode.previewFps}fps',
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]);
      },
    );
  }
}


// lib/core/services/haptic_service.dart
// Haptic feedback throughout the app for premium feel
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticService {
  static final HapticService _i = HapticService._();
  factory HapticService() => _i;
  HapticService._();

  bool _enabled = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('haptic_enabled') ?? true;
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_enabled', v);
  }

  bool get isEnabled => _enabled;

  // ── Feedback types ─────────────────────────────────────────────────────────

  /// Light tap — button press, selection
  void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium — drag start, panel open
  void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy — long press, delete, important action
  void heavy() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection changed — slider, tab switch
  void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Success — export complete, save done
  void success() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    Future.delayed(
        const Duration(milliseconds: 80), HapticFeedback.lightImpact);
    Future.delayed(
        const Duration(milliseconds: 160), HapticFeedback.mediumImpact);
  }

  /// Error — validation fail, can't do action
  void error() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(
        const Duration(milliseconds: 100), HapticFeedback.heavyImpact);
  }

  /// Timeline snap — clip snaps to another
  void snap() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Clip trim — dragging trim handle
  void trim() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }
}

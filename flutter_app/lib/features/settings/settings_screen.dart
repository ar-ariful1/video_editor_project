// lib/features/settings/settings_screen.dart — Complete settings
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_theme.dart';
import '../../core/services/haptic_service.dart';
import '../../core/utils/app_icons.dart';
import '../../core/utils/utils.dart';
import '../legal/legal_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _res = '1080p';
  int _fps = 30;
  bool _autoSave = true, _cloudSync = true, _haptic = true, _wifiOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _res = p.getString('default_resolution') ?? '1080p';
      _fps = p.getInt('default_fps') ?? 30;
      _autoSave = p.getBool('auto_save') ?? true;
      _cloudSync = p.getBool('cloud_sync') ?? true;
      _haptic = p.getBool('haptic_enabled') ?? true;
      _wifiOnly = p.getBool('wifi_only_upload') ?? false;
      _loading = false;
    });
  }

  Future<void> _s(String k, dynamic v) async {
    final p = await SharedPreferences.getInstance();
    if (v is bool) await p.setBool(k, v);
    if (v is String) await p.setString(k, v);
    if (v is int) await p.setInt(k, v);
    HapticService().selection();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          backgroundColor: AppTheme.bg,
          body:
              Center(child: CircularProgressIndicator(color: AppTheme.accent)));
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar:
          AppBar(backgroundColor: AppTheme.bg2, title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        _Hdr('Export Defaults'),
        _Sel('Default Resolution', _res, ['720p', '1080p', '4K'], (v) {
          setState(() => _res = v);
          _s('default_resolution', v);
        }),
        _Sel('Default FPS', '$_fps fps', ['24 fps', '30 fps', '60 fps'], (v) {
          final f = int.parse(v.split(' ').first);
          setState(() => _fps = f);
          _s('default_fps', f);
        }),
        _Hdr('Storage & Sync'),
        _SW(Icons.cloud_sync_rounded, 'Cloud Sync',
            'Sync projects automatically', _cloudSync, (v) {
          setState(() => _cloudSync = v);
          _s('cloud_sync', v);
        }),
        _SW(Icons.wifi_rounded, 'Wi-Fi Only Uploads', 'Upload only on Wi-Fi',
            _wifiOnly, (v) {
          setState(() => _wifiOnly = v);
          _s('wifi_only_upload', v);
        }),
        _Hdr('Editor'),
        _SW(Icons.save_rounded, 'Auto-Save', 'Save every 30 seconds', _autoSave,
            (v) {
          setState(() => _autoSave = v);
          _s('auto_save', v);
        }),
        _Hdr('Accessibility'),
        _SW(Icons.vibration_rounded, 'Haptic Feedback', 'Vibration on actions',
            _haptic, (v) {
          setState(() => _haptic = v);
          _s('haptic_enabled', v);
          HapticService().setEnabled(v);
        }),
        _Hdr('Legal'),
        _Act(
            Icons.description_rounded,
            'Terms of Service',
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LegalScreen(type: LegalType.terms)))),
        _Act(
            Icons.privacy_tip_rounded,
            'Privacy Policy',
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const LegalScreen(type: LegalType.privacy)))),
        _Hdr('Account'),
        _Act(Icons.delete_forever_rounded, 'Delete Account',
            () => showError(context, 'Contact support@videoeditorpro.app'),
            color: AppTheme.accent4),
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Column(children: [
              Text('ClipCut',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              Text('v1.0.0 · Made with ❤️',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11))
            ]))),
      ]),
    );
  }

  Widget _Hdr(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(t.toUpperCase(),
          style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)));
  Widget _SW(IconData i, String t, String s, bool v, ValueChanged<bool> c) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.bg2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(i, color: AppTheme.textSecondary, size: 18),
            ),
            title: Text(t,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(s,
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            value: v,
            onChanged: c,
            activeColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
      );
  Widget _Act(IconData i, String t, VoidCallback f,
          {Color color = AppTheme.textPrimary}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.bg2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(i,
                  color: color == AppTheme.textPrimary
                      ? AppTheme.textSecondary
                      : color,
                  size: 18),
            ),
            title: Text(t, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textTertiary, size: 18),
            onTap: f,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
  Widget _Sel(String t, String v, List<String> opts, ValueChanged<String> c) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
            title: Text(t,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(v,
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary, size: 18)
            ]),
            onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: AppTheme.bg2,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 8),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
                      Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(t,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700))),
                      ...opts.map((o) => ListTile(
                          title: Text(o,
                              style: TextStyle(
                                  color: o == v
                                      ? AppTheme.accent
                                      : AppTheme.textPrimary,
                                  fontWeight: o == v ? FontWeight.w700 : FontWeight.normal)),
                          trailing: o == v
                              ? const Icon(Icons.check_rounded,
                                  color: AppTheme.accent)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            c(o);
                          })),
                      const SizedBox(height: 24)
                    ])),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
}

// lib/features/home/main_nav_screen.dart — Complete navigation
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/utils/app_icons.dart';
import '../home/home_screen.dart';
import '../templates/marketplace/template_marketplace_screen.dart';
import '../profile/profile_screen.dart';
import '../favorites/favorites_screen.dart';
import '../editor/editor_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});
  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _index = 0;
  static const _pages = [
    HomeScreen(),
    TemplateMarketplaceScreen(),
    FavoritesScreen(),
    ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            color: AppTheme.bg2,
            border:
                Border(top: BorderSide(color: AppTheme.border, width: 0.5))),
        child: SafeArea(
            top: false,
            child: SizedBox(
                height: 60,
                child: Row(children: [
                  _T(AppIcons.home, 'Home', _index == 0,
                      () => setState(() => _index = 0)),
                  _T(AppIcons.templates, 'Templates', _index == 1,
                      () => setState(() => _index = 1)),
                  Expanded(
                      child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditorScreen(),
                            fullscreenDialog: true)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 48,
                              height: 32,
                              decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 24)),
                          const SizedBox(height: 4),
                          const Text('Edit',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  )),
                  _T(AppIcons.star, 'Saved', _index == 2,
                      () => setState(() => _index = 2)),
                  _T(AppIcons.profile, 'Profile', _index == 3,
                      () => setState(() => _index = 3)),
                ]))),
      ),
    );
  }

  Widget _T(IconData icon, String label, bool sel, VoidCallback onTap) =>
      Expanded(
          child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: sel ? Colors.white : AppTheme.textTertiary, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : AppTheme.textTertiary,
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
        ]),
      ));
}

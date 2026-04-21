// lib/features/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _pages = [
    _OnbPage(
        emoji: '🎬',
        title: 'Professional Timeline',
        subtitle:
            'Multi-track editing with GPU-accelerated preview at 60fps. Trim, split, ripple delete, and more.',
        color: AppTheme.accent),
    _OnbPage(
        emoji: '✨',
        title: '50+ Effects & Transitions',
        subtitle:
            'Glitch, VHS, blur, color grading, LUT support, and 30+ 3D transitions. GPU-powered in real time.',
        color: AppTheme.accent2),
    _OnbPage(
        emoji: '🤖',
        title: 'AI-Powered Tools',
        subtitle:
            'Auto captions with Whisper AI, background removal, object tracking, beat detection and 4K upscaling.',
        color: AppTheme.accent3),
    _OnbPage(
        emoji: '🎨',
        title: 'Template Marketplace',
        subtitle:
            'Hundreds of professional templates for weddings, travel, food, and more. One tap to apply.',
        color: AppTheme.pink),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', true);
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
          child: Column(children: [
        // Skip button
        Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: _finish,
            child: const Text('Skip',
                style: TextStyle(color: AppTheme.textTertiary)),
          ),
        ),

        // Pages
        Expanded(
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _OnbPageWidget(page: _pages[i]),
          ),
        ),

        // Dots
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? _pages[_page].color : AppTheme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
        const SizedBox(height: 24),

        // Next / Get Started button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (_page < _pages.length - 1) {
                  _ctrl.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut);
                } else {
                  _finish();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _pages[_page].color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _page < _pages.length - 1 ? 'Next →' : '🚀 Get Started',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ])),
    );
  }
}

class _OnbPage {
  final String emoji, title, subtitle;
  final Color color;
  const _OnbPage(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.color});
}

class _OnbPageWidget extends StatelessWidget {
  final _OnbPage page;
  const _OnbPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: page.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: page.color.withValues(alpha: 0.3), width: 2),
          ),
          child: Center(
              child: Text(page.emoji, style: const TextStyle(fontSize: 56))),
        ),
        const SizedBox(height: 36),
        Text(page.title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Text(page.subtitle,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 15, height: 1.6),
            textAlign: TextAlign.center),
      ]),
    );
  }
}


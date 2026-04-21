// lib/features/profile/profile_screen.dart — Complete profile
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app_theme.dart';
import '../../core/utils/app_icons.dart';
import '../../core/utils/utils.dart';
import '../auth/auth_bloc.dart';
import '../subscription/subscription_bloc.dart';
import 'profile_edit_screen.dart';
import 'analytics_screen.dart';
import '../settings/settings_screen.dart';
import '../legal/legal_screen.dart';
import '../export/export_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final sub = context.watch<SubscriptionBloc>().state;
    final isAuthenticated = auth is AuthAuthenticated;
    final name = isAuthenticated ? (auth.displayName ?? 'Creator') : 'Create Account';
    final email = isAuthenticated ? auth.email : 'Sign in to sync your projects';
    final plan = sub.plan;
    final pC = plan == 'premium'
        ? AppTheme.accent3
        : plan == 'pro'
            ? AppTheme.accent
            : AppTheme.textTertiary;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 210,
          pinned: true,
          backgroundColor: AppTheme.bg2,
          actions: [
            IconButton(
                icon: const Icon(Icons.settings_rounded,
                    color: AppTheme.textSecondary),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())))
          ],
          flexibleSpace: FlexibleSpaceBar(
              background: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppTheme.bg2, AppTheme.bg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 44),
              GestureDetector(
                  onTap: () {
                    if (isAuthenticated) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileEditScreen()));
                    } else {
                      Navigator.pushNamed(context, '/login');
                    }
                  },
                  child: Stack(children: [
                    Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isAuthenticated
                                ? const LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)
                                : LinearGradient(
                                    colors: [AppTheme.bg2, AppTheme.border],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                            border: Border.all(color: AppTheme.bg2, width: 3)),
                        child: Center(
                            child: Icon(
                                isAuthenticated ? null : Icons.person_add_rounded,
                                color: isAuthenticated ? Colors.white : AppTheme.textTertiary,
                                size: isAuthenticated ? 32 : 40,
                            ) ?? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700)))),
                    if (isAuthenticated)
                      Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                  color: AppTheme.accent, shape: BoxShape.circle),
                              child: const Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 13))),
                  ])),
              const SizedBox(height: 8),
              Text(name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              Text(email,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11)),
              const SizedBox(height: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: pC.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: pC.withValues(alpha: 0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        plan == 'premium'
                            ? '👑'
                            : plan == 'pro'
                                ? '⚡'
                                : '🆓',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                        plan == 'premium'
                            ? 'PREMIUM'
                            : plan == 'pro'
                                ? 'PRO'
                                : 'FREE',
                        style: TextStyle(
                            color: pC,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ])),
            ]),
          )),
        ),
        SliverList(
            delegate: SliverChildListDelegate([
          if (isAuthenticated && plan != 'premium') _UpgradeBanner(plan: plan),
          if (!isAuthenticated) _LoginBanner(),
          const SizedBox(height: 4),
          _hdr('Content'),
          _tile(context, AppIcons.projects, 'My Projects',
              () => Navigator.pushNamed(context, '/home')),
          _tile(
              context,
              AppIcons.history_rounded,
              'Export History',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ExportHistoryScreen()))),
          _tile(
              context,
              AppIcons.analytics_rounded,
              'My Stats',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UserAnalyticsScreen()))),
          _hdr('Account'),
          _tile(
              context,
              AppIcons.edit_rounded,
              'Edit Profile',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen()))),
          _tile(
              context,
              AppIcons.settings,
              'Settings',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          _hdr('Legal'),
          _tile(
              context,
              Icons.description_rounded,
              'Terms of Service',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const LegalScreen(type: LegalType.terms)))),
          _tile(
              context,
              Icons.privacy_tip_rounded,
              'Privacy Policy',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const LegalScreen(type: LegalType.privacy)))),
          const SizedBox(height: 16),
          if (isAuthenticated)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.accent4),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: AppTheme.accent4, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accent4),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                )),
          const SizedBox(height: 80),
        ])),
      ]),
    );
  }

  Widget _hdr(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(t.toUpperCase(),
          style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)));
  Widget _tile(BuildContext ctx, IconData i, String l, VoidCallback t) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.bg2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(i, color: AppTheme.textSecondary, size: 18),
            ),
            title: Text(l,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textTertiary, size: 18),
            onTap: t,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            dense: true),
      );

  Future<void> _logout(BuildContext ctx) async {
    final ok = await showConfirmDialog(ctx,
        title: 'Sign Out?',
        message: 'Your projects are saved locally.',
        confirmLabel: 'Sign Out');
    if (ok == true && ctx.mounted) {
      await FirebaseAuth.instance.signOut();
      ctx.read<AuthBloc>().add(const SignOut());
    }
  }
}

class _LoginBanner extends StatelessWidget {
  @override
  Widget build(BuildContext c) => GestureDetector(
      onTap: () => Navigator.pushNamed(c, '/login'),
      child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            const Text('👋', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Sign in to Clip Cut',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  Text('Save projects to cloud & sync devices',
                      style:
                          TextStyle(color: AppTheme.textSecondary, fontSize: 11))
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Sign In',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)))
          ])));
}

class _UpgradeBanner extends StatelessWidget {
  final String plan;
  const _UpgradeBanner({required this.plan});
  @override
  Widget build(BuildContext c) => GestureDetector(
      onTap: () => Navigator.pushNamed(c, '/subscription'),
      child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accent2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]),
          child: Row(children: [
            const Text('👑', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(plan == 'pro' ? 'Upgrade to Premium' : 'Upgrade to Pro',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  Text(
                      plan == 'pro'
                          ? '4K, unlimited AI · \$9.99/mo'
                          : 'No watermark, 1080p · \$4.99/mo',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11))
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Upgrade',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)))
          ])));
}


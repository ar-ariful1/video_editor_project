// lib/core/utils/app_router.dart — All routes centralized
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/home/main_nav_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../features/subscription/subscription_bloc.dart';
import '../../features/templates/marketplace/template_marketplace_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/profile_edit_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/export/export_history_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const editor = '/editor';
  static const subscription = '/subscription';
  static const templates = '/templates';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const onboarding = '/onboarding';
  static const exportHistory = '/exports';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings s) {
    switch (s.name) {
      case AppRoutes.login:
        return _fade(const LoginScreen());
      case AppRoutes.forgotPassword:
        return _slide(const ForgotPasswordScreen());
      case AppRoutes.home:
        return _fade(const MainNavScreen());
      case AppRoutes.profile:
        return _slide(const ProfileScreen());
      case AppRoutes.profileEdit:
        return _slide(const ProfileEditScreen());
      case AppRoutes.notifications:
        return _slide(const NotificationsScreen());
      case AppRoutes.settings:
        return _slide(const SettingsScreen());
      case AppRoutes.onboarding:
        return _fade(const OnboardingScreen());
      case AppRoutes.exportHistory:
        return _slide(const ExportHistoryScreen());
      case AppRoutes.templates:
        return _slide(const TemplateMarketplaceScreen());
      case AppRoutes.editor:
        final args = s.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
            builder: (_) => EditorScreen(projectId: args?['projectId']),
            fullscreenDialog: true);
      case AppRoutes.subscription:
        return MaterialPageRoute(
            builder: (ctx) => BlocProvider.value(
                value: ctx.read<SubscriptionBloc>(),
                child: const SubscriptionScreen()),
            fullscreenDialog: true);
      default:
        return MaterialPageRoute(
            builder: (_) => Scaffold(
                backgroundColor: const Color(0xFF0F0F13),
                body: Center(
                    child: Text('404: ${s.name}',
                        style: const TextStyle(color: Colors.white54)))));
    }
  }

  static PageRoute _slide(Widget page) => PageRouteBuilder(
      pageBuilder: (_, a, __) => page,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child),
      transitionDuration: const Duration(milliseconds: 280));

  static PageRoute _fade(Widget page) => PageRouteBuilder(
      pageBuilder: (_, a, __) => page,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 220));
}

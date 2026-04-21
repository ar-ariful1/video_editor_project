// lib/main.dart — Complete app entry 2026 edition
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'firebase_options.dart';
import 'app_theme.dart';
import 'core/utils/app_router.dart';
import 'core/bloc/timeline_bloc.dart';
import 'core/services/monitoring_service.dart';
import 'core/services/device_profile_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/ab_test_service.dart';
import 'core/services/proxy_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/ai_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/background_export_service.dart';
import 'core/services/error_handler_service.dart';  // যোগ করুন
import 'core/engine/performance_manager.dart';
import 'core/widgets/in_app_notification_banner.dart';
import 'features/auth/auth_bloc.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_nav_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/subscription/subscription_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Initialize local error handler (logs to terminal and file)
  final errorService = ErrorHandlerService();
  errorService.initialize();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Record errors to Firebase Crashlytics as well
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    // ErrorHandlerService already handles this
  };
  
  // Init all services
  await DeviceProfileService().init();
  await RemoteConfigService().init();
  await HapticService().init();
  await BackgroundExportService().init();
  await ProxyService().init();
  await PerformanceManager().init();
  await DeepLinkService().init();
  
  runApp(const VideoEditorApp());
}

class VideoEditorApp extends StatelessWidget {
  const VideoEditorApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()..add(const CheckAuthStatus())),
        BlocProvider(create: (_) => TimelineBloc()),
        BlocProvider(create: (_) => SubscriptionBloc()),
      ],
      child: MaterialApp(
        title: 'Clip Cut',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        navigatorKey: DeepLinkService().navigatorKey,
        home: InAppNotifOverlay(child: const _AppRouter()),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();
  
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (ctx, state) async {
        if (state is AuthAuthenticated) {
          await MonitoringService().init(userId: state.userId);
          await ABTestService().init(state.userId);
          ctx.read<SubscriptionBloc>().add(const LoadSubscription());
          
          // Mark onboarding and first-time login as done
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_done', true);
          await prefs.setBool('is_first_run', false);

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await RemoteConfigService().fetch();
            if (ctx.mounted) {
              await RemoteConfigService().showForceUpdateDialog(ctx);
            }
          });
        }
      },
      builder: (ctx, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const SplashScreen();
        }

        return FutureBuilder<Map<String, bool>>(
          future: SharedPreferences.getInstance().then((prefs) => {
                'onboarding_done': prefs.getBool('onboarding_done') ?? false,
                'is_first_run': prefs.getBool('is_first_run') ?? true,
              }),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SplashScreen();
            }

            final onboardingDone = snapshot.data!['onboarding_done'] ?? false;
            final isFirstRun = snapshot.data!['is_first_run'] ?? true;

            // যদি প্রথমবার রান হয় অথবা লগইন করা না থাকে
            if (isFirstRun || state is AuthUnauthenticated) {
              return const LoginScreen();
            }

            if (onboardingDone) {
              return const MainNavScreen();
            } else {
              return const OnboardingScreen();
            }
          },
        );
      },
    );
  }
}
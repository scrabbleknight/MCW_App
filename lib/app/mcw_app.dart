import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:military_calisthenics_women/app/startup_shell.dart';
import 'package:military_calisthenics_women/core/theme/tactical_theme.dart';
import 'package:military_calisthenics_women/core/theme/theme_controller.dart';
import 'package:military_calisthenics_women/features/home/presentation/home_screen.dart';
import 'package:military_calisthenics_women/features/launch/presentation/launch_animation_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/onboarding_screen.dart';
import 'package:military_calisthenics_women/features/paywall/application/auth_controller.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:provider/provider.dart';

class McwApp extends StatelessWidget {
  const McwApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => AuthController()..load()),
        ChangeNotifierProvider(create: (_) => OnboardingController()..load()),
        ChangeNotifierProvider(create: (_) => PurchaseController()..load()),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'Military Calisthenics for Women',
            debugShowCheckedModeBanner: false,
            // MCW ships a single dark tactical theme; the ThemeController
            // is still wired for a future light variant.
            theme: TacticalTheme.dark(),
            darkTheme: TacticalTheme.dark(),
            themeMode: ThemeMode.dark,
            supportedLocales: const [Locale('en', 'GB'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const _AppFlowGate(),
          );
        },
      ),
    );
  }
}

class _AppFlowGate extends StatefulWidget {
  const _AppFlowGate();

  @override
  State<_AppFlowGate> createState() => _AppFlowGateState();
}

class _AppFlowGateState extends State<_AppFlowGate> {
  // Kept per-process, not persisted — so a fresh cold start (first launch,
  // or after force-quit) plays the intro once, but the intro doesn't replay
  // when the OS restores the app from the background.
  bool _launchAnimationDone = false;

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingController>();
    final auth = context.watch<AuthController>();
    final theme = context.watch<ThemeController>();

    if (!onboarding.isLoaded || !auth.isLoaded || !theme.isLoaded) {
      return const StartupScaffold(
        title: 'Loading your plan',
        message: 'Restoring your workouts, streak, and progress.',
      );
    }

    if (!_launchAnimationDone) {
      return LaunchAnimationScreen(
        assetPath: 'assets/launch_animation/newlaunchvid.mov',
        onComplete: () => setState(() => _launchAnimationDone = true),
      );
    }

    if (!onboarding.hasCompletedOnboarding) {
      return const OnboardingScreen();
    }

    return const HomeScreen();
  }
}

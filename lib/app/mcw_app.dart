import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:military_calisthenics_women/app/startup_shell.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/core/theme/tactical_theme.dart';
import 'package:military_calisthenics_women/core/theme/theme_controller.dart';
import 'package:military_calisthenics_women/features/home/presentation/home_screen.dart';
import 'package:military_calisthenics_women/features/launch/presentation/launch_animation_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/onboarding_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/current_weight_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/height_step.dart';
import 'package:military_calisthenics_women/features/paywall/application/auth_controller.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/connected_paywall.dart';
import 'package:military_calisthenics_women/features/plan/application/sounds_controller.dart';
import 'package:military_calisthenics_women/features/referrals/application/referral_controller.dart';
import 'package:military_calisthenics_women/features/health/application/health_controller.dart';
import 'package:military_calisthenics_women/features/reminders/application/reminder_controller.dart';
import 'package:military_calisthenics_women/features/profile/application/body_progress_controller.dart';
import 'package:military_calisthenics_women/features/profile/application/profile_avatar_controller.dart';
import 'package:military_calisthenics_women/features/progression/application/rank_progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/starred_workouts_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/training_progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/workout_history_controller.dart';
import 'package:military_calisthenics_women/features/custom_workout/application/custom_workouts_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/workout_settings_controller.dart';
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
        ChangeNotifierProvider(create: (_) => ReferralController()),
        ChangeNotifierProvider(
          create: (context) => PurchaseController()
            // Purchases go to the referral server while it's waiting on one.
            ..onPurchase = context.read<ReferralController>().reportPurchase
            ..load(),
        ),
        ChangeNotifierProvider(create: (_) => SoundsController()..load()),
        // Not lazy: loading re-registers the scheduled workout reminders on
        // every launch, even if the reminder screen is never opened.
        ChangeNotifierProvider(
            lazy: false, create: (_) => ReminderController()..load()),
        ChangeNotifierProvider(create: (_) => HealthController()..load()),
        ChangeNotifierProvider(
            create: (_) => StarredWorkoutsController()..load()),
        ChangeNotifierProvider(create: (_) => ProgressController()..load()),
        ChangeNotifierProvider(
            create: (_) => TrainingProgressController()..load()),
        ChangeNotifierProvider(
            create: (_) => WorkoutHistoryController()..load()),
        ChangeNotifierProvider(
            create: (_) => WorkoutSettingsController()..load()),
        ChangeNotifierProvider(
            create: (_) => CustomWorkoutsController()..load()),
        ChangeNotifierProvider(
            create: (_) => BodyProgressController()..load()),
        ChangeNotifierProvider(
            create: (_) => ProfileAvatarController()..load()),
        ChangeNotifierProvider(
            create: (_) => RankProgressController()..load()),
      ],
      child: Builder(
        builder: (context) {
          final themeController = context.watch<ThemeController>();
          return MaterialApp(
            title: 'Military Calisthenics for Women',
            debugShowCheckedModeBanner: false,
            theme: TacticalTheme.light(),
            darkTheme: TacticalTheme.dark(),
            themeMode: themeController.isLoaded
                ? themeController.themeMode
                : ThemeMode.dark,
            supportedLocales: const [Locale('en', 'GB'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const _AppFlowGate(),
            // Force status-bar icon colour on every route (including ones
            // without an AppBar) so it stays legible under both themes.
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: isDark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: child ?? const SizedBox.shrink(),
              );
            },
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
  bool _bodySeeded = false;

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

    if (!_bodySeeded && onboarding.hasCompletedOnboarding) {
      _bodySeeded = true;
      final body = context.read<BodyProgressController>();
      final currentW = onboarding.answerFor<WeightAnswer>('current_weight');
      final goalW = onboarding.answerFor<WeightAnswer>('goal_weight');
      final h = onboarding.answerFor<HeightAnswer>('height');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        body.seedIfEmpty(
          weightKg: currentW?.kg,
          heightCm: h?.cm,
          goalKg: goalW?.kg,
        );
      });
    }

    if (!_launchAnimationDone) {
      return LaunchAnimationScreen(
        onComplete: () => setState(() => _launchAnimationDone = true),
      );
    }

    if (!onboarding.hasCompletedOnboarding) {
      return const OnboardingScreen();
    }

    return const _SubscriptionGate();
  }
}

/// After onboarding, the app stays open only while the store says the
/// subscription is active. Re-checks on launch and whenever the app returns
/// to the foreground after a while, so a cancelled subscription ends access
/// once it expires — and "Log in" on the welcome screen can't skip the
/// paywall.
class _SubscriptionGate extends StatefulWidget {
  const _SubscriptionGate();

  @override
  State<_SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<_SubscriptionGate>
    with WidgetsBindingObserver {
  static const _recheckAfter = Duration(hours: 6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PurchaseController>().checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PurchaseController>().checkAccess(
            ifOlderThan: _recheckAfter,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchaseController>();
    return switch (purchases.access) {
      AppAccess.allowed => const HomeScreen(),
      AppAccess.checking => const StartupScaffold(
          title: 'Checking your subscription',
          message: 'This only takes a moment.',
        ),
      // A purchase or restore flips access to allowed, which rebuilds this
      // gate into the home screen.
      AppAccess.notSubscribed => Scaffold(
          backgroundColor: context.palette.abyss,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: const ConnectedPaywall(),
            ),
          ),
        ),
      AppAccess.needsConnection => StartupScaffold(
          title: 'Connect to the internet',
          message: "We couldn't confirm your subscription for a while. "
              'Connect to the internet and try again to keep training.',
          isLoading: false,
          actionLabel: 'Try again',
          onAction: purchases.checkAccess,
        ),
    };
  }
}

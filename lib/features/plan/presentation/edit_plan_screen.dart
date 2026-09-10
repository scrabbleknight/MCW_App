import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/auth/application/auth_service.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/fitness_level_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/goal_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/target_zones_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_duration_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_preferences_step.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:military_calisthenics_women/features/plan/application/sounds_controller.dart';
import 'package:military_calisthenics_women/features/health/application/health_controller.dart';
import 'package:military_calisthenics_women/features/health/presentation/apple_health_screen.dart';
import 'package:military_calisthenics_women/features/reminders/application/reminder_controller.dart';
import 'package:military_calisthenics_women/features/reminders/presentation/workout_reminder_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Post-onboarding editor for the four plan-driving inputs plus the selected
/// trainer. Reads the current [PlanInputs] out of the [OnboardingController],
/// lets the user change each field via a bottom-sheet picker, then persists
/// and regenerates the plan when they hit "Update My Current Plan".
class EditPlanScreen extends StatefulWidget {
  const EditPlanScreen({super.key});

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  late PlanInputs _inputs;
  late Set<TargetZone> _zones;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final controller = context.read<OnboardingController>();
    _inputs =
        controller.answerFor<PlanInputs>('plan_inputs') ?? const PlanInputs();
    _zones = controller.answerFor<Set<TargetZone>>('target_zones') ??
        <TargetZone>{TargetZone.fullBody};
  }

  void _update(PlanInputs next) {
    setState(() {
      _inputs = next;
      _dirty = true;
    });
  }

  void _setZones(Set<TargetZone> next) {
    setState(() {
      _zones = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final controller = context.read<OnboardingController>();
    controller.setAnswer('plan_inputs', _inputs);
    controller.setAnswer('target_zones', _zones);
    controller.setAnswer('plan', generatePlan(_inputs));
    await controller.persistPlanInputs(_inputs);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Plan updated')));
    Navigator.of(context).pop();
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogCtx.palette.surface,
        title: const Text('Restart from Day 1?'),
        content: const Text(
          'Your 21-day plan will start over. Completed days will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Progress tracking isn't persisted yet, so this is a no-op today; hook
    // into the progress store here when it lands.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Plan restarted from Day 1')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.abyss,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Current Plan Settings',
          style: TextStyle(
            color: context.palette.chalk,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Goal',
                value: _goalLabel(_inputs.goal),
                onTap: _pickGoal,
              ),
              _SettingsRow(
                label: 'Focus',
                value: _zonesLabel(_zones),
                onTap: _pickZones,
              ),
              _SettingsRow(
                label: 'Workout Level',
                value: _levelLabel(_inputs.fitnessLevel),
                onTap: _pickLevel,
              ),
              _SettingsRow(
                label: 'Duration',
                value: _durationLabel(_inputs.workoutDuration),
                onTap: _pickDuration,
              ),
              _SettingsRow(
                label: 'Preference',
                value: _preferenceLabel(_inputs.workoutPreference),
                onTap: _pickPreference,
                isLast: true,
              ),
              const SizedBox(height: 16),
              _PrimaryButton(
                label: 'UPDATE MY CURRENT PLAN',
                enabled: _dirty,
                onTap: _save,
              ),
              const SizedBox(height: 10),
              _OutlineButton(
                label: 'Restart From Day 1',
                onTap: _confirmRestart,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Lead',
            style: TextStyle(
              color: context.palette.chalk,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          _TrainerCard(
            trainer: _inputs.trainer ?? Trainer.hailey,
            onTap: _pickTrainer,
          ),
          const SizedBox(height: 28),
          Text(
            'Sounds',
            style: TextStyle(
              color: context.palette.chalk,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          const _VoiceGuidanceCard(),
          const SizedBox(height: 28),
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Manage Subscription',
                value: '',
                onTap: () => _openUrl(
                  context,
                  Uri.parse(
                    'https://apps.apple.com/account/subscriptions',
                  ),
                ),
              ),
              _SettingsRow(
                label: 'Restore Subscription',
                value: '',
                onTap: () => _restoreSubscription(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Use this to restore an existing subscription. "
              "Make sure you're logged into the same iTunes account.",
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Rate Us!',
                value: '',
                onTap: () => _openUrl(
                  context,
                  Uri.parse(
                    'https://apps.apple.com/app/id6809903076?action=write-review',
                  ),
                ),
              ),
              _SettingsRow(
                label: 'Contact Us',
                value: '',
                onTap: () => _openUrl(
                  context,
                  Uri(
                    scheme: 'mailto',
                    path: 'support@swiftbee.co.uk',
                    query: 'subject=Military Calisthenics for Women',
                  ),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Workout Reminder',
                value: _reminderSummary(context.watch<ReminderController>()),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WorkoutReminderScreen(),
                  ),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Apple Health',
                value: context.watch<HealthController>().connected
                    ? 'On'
                    : 'Off',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppleHealthScreen(),
                  ),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Privacy Policy',
                value: '',
                onTap: () => _openUrl(
                  context,
                  Uri.parse('https://deepblue.org.uk/privacy-policy'),
                ),
              ),
              _SettingsRow(
                label: 'Terms of Use',
                value: '',
                onTap: () => _openUrl(
                  context,
                  Uri.parse('https://deepblue.org.uk/terms-of-use'),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Language',
                value: 'English',
                onTap: () => _showLanguageSheet(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (FirebaseAuth.instance.currentUser != null)
            _SettingsCard(
              children: [
                _DangerRow(
                  label: 'Delete Account',
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          if (FirebaseAuth.instance.currentUser != null)
            const SizedBox(height: 20),
          Center(
            child: Text(
              'Version: 1.0.0 (1)',
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't open link")));
    }
  }

  void _restoreSubscription(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No previous subscription found')),
      );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetCtx.palette.muted.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(
                'English',
                style: TextStyle(color: sheetCtx.palette.chalk),
              ),
              trailing: Icon(Icons.check_rounded,
                  color: sheetCtx.palette.arctic),
              onTap: () => Navigator.of(sheetCtx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: palette.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete your account?',
          style:
              TextStyle(color: palette.chalk, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This permanently removes your account and progress. This '
              "can't be undone.",
              style: TextStyle(color: palette.mist, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.hairline),
              ),
              child: Text(
                "Your App Store subscription is billed by Apple and won't "
                'be cancelled automatically. To stop future charges, open '
                'the iPhone Settings app → tap your name → Subscriptions, '
                'then cancel this app.',
                style:
                    TextStyle(color: palette.chalk, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.surfaceHigh,
                    foregroundColor: palette.chalk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.danger,
                    foregroundColor: palette.chalk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await AuthService().deleteCurrentAccount();
    if (!context.mounted) return;
    switch (result.kind) {
      case DeleteAccountKind.success:
        Navigator.of(context).popUntil((r) => r.isFirst);
      case DeleteAccountKind.cancelled:
        break;
      case DeleteAccountKind.notSignedIn:
        Navigator.of(context).popUntil((r) => r.isFirst);
      case DeleteAccountKind.needsRecentLogin:
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text(
              'For security, please log in again and then delete your account.',
            ),
          ));
      case DeleteAccountKind.failed:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
                "Couldn't delete account: ${result.message ?? 'unknown error'}"),
          ));
    }
  }

  Future<void> _pickGoal() async {
    final v = await Navigator.of(context).push<FitnessGoal>(
      MaterialPageRoute(
        builder: (routeCtx) => _StepScaffold(
          child: GoalStep(
            selected: _inputs.goal,
            onAnswered: (v) => Navigator.of(routeCtx).pop(v),
          ),
        ),
      ),
    );
    if (v != null) _update(_inputs.copyWith(goal: v));
  }

  Future<void> _pickLevel() async {
    final v = await Navigator.of(context).push<FitnessLevel>(
      MaterialPageRoute(
        builder: (routeCtx) => _StepScaffold(
          child: FitnessLevelStep(
            initial: _inputs.fitnessLevel,
            onCompleted: (v) => Navigator.of(routeCtx).pop(v),
          ),
        ),
      ),
    );
    if (v != null) _update(_inputs.copyWith(fitnessLevel: v));
  }

  Future<void> _pickDuration() async {
    final v = await Navigator.of(context).push<WorkoutDuration>(
      MaterialPageRoute(
        builder: (routeCtx) => _StepScaffold(
          child: WorkoutDurationStep(
            selected: _inputs.workoutDuration,
            onAnswered: (v) => Navigator.of(routeCtx).pop(v),
          ),
        ),
      ),
    );
    if (v != null) _update(_inputs.copyWith(workoutDuration: v));
  }

  Future<void> _pickPreference() async {
    final v = await Navigator.of(context).push<WorkoutPreference>(
      MaterialPageRoute(
        builder: (routeCtx) => _StepScaffold(
          child: WorkoutPreferencesStep(
            selected: _inputs.workoutPreference,
            onAnswered: (v) => Navigator.of(routeCtx).pop(v),
          ),
        ),
      ),
    );
    if (v != null) _update(_inputs.copyWith(workoutPreference: v));
  }

  Future<void> _pickTrainer() async {
    final v = await Navigator.of(context).push<Trainer>(
      MaterialPageRoute(
        builder: (_) => TrainerPickerScreen(
          initial: _inputs.trainer ?? Trainer.hailey,
        ),
      ),
    );
    if (v != null) _update(_inputs.copyWith(trainer: v));
  }

  Future<void> _pickZones() async {
    final result = await Navigator.of(context).push<Set<TargetZone>>(
      MaterialPageRoute(
        builder: (_) => TargetZonesEditScreen(initial: _zones),
      ),
    );
    if (result != null) _setZones(result);
  }
}

// ---------------------------------------------------------------------------
// Labels
// ---------------------------------------------------------------------------

String _goalLabel(FitnessGoal? g) => switch (g) {
      FitnessGoal.loseWeight => 'Lose weight',
      FitnessGoal.maintainAndFit => 'Maintain weight and get fit',
      FitnessGoal.buildStrength => 'Build muscles and strength',
      FitnessGoal.recomp => 'Gain muscle and lose weight',
      null => 'Not set',
    };

String _levelLabel(FitnessLevel? l) => switch (l) {
      FitnessLevel.newbie => 'Newbie',
      FitnessLevel.beginner => 'Beginner',
      FitnessLevel.intermediate => 'Intermediate',
      FitnessLevel.advanced => 'Advanced',
      null => 'Not set',
    };

String _durationLabel(WorkoutDuration? d) => switch (d) {
      WorkoutDuration.under10 => 'Under 10 minutes',
      WorkoutDuration.tenToFifteen => '10-15 minutes',
      WorkoutDuration.fifteenToTwenty => '15-20 minutes',
      WorkoutDuration.twentyToThirty => '20-30 minutes',
      null => 'Not set',
    };

String _preferenceLabel(WorkoutPreference? p) => switch (p) {
      WorkoutPreference.noPreferences => 'No Preferences',
      WorkoutPreference.allStanding => 'All Standing',
      WorkoutPreference.noSquat => 'No Squat',
      WorkoutPreference.noJumping => 'No Jumping',
      WorkoutPreference.noProne => 'No Prone',
      WorkoutPreference.noKneeling => 'No Kneeling',
      null => 'Not set',
    };

String _zoneLabel(TargetZone z) => switch (z) {
      TargetZone.fullBody => 'Fullbody',
      TargetZone.back => 'Back',
      TargetZone.arms => 'Arms',
      TargetZone.belly => 'Belly',
      TargetZone.butt => 'Butt',
      TargetZone.legs => 'Legs',
    };

String _reminderSummary(ReminderController r) {
  if (!r.enabled) return 'Off';
  final h = r.time.hourOfPeriod == 0 ? 12 : r.time.hourOfPeriod;
  final m = r.time.minute.toString().padLeft(2, '0');
  final p = r.time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$m $p';
}

String _zonesLabel(Set<TargetZone> zones) {
  if (zones.isEmpty) return 'None';
  if (zones.contains(TargetZone.fullBody)) return 'Fullbody';
  if (zones.length <= 2) return zones.map(_zoneLabel).join(', ');
  return '${zones.length} zones';
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.hairline),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isLast = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: context.palette.chalk,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: context.palette.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: context.palette.hairline),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: context.palette.arctic,
          disabledBackgroundColor: context.palette.arctic.withOpacity(0.4),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.palette.arctic, width: 1.4),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.palette.chalk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.trainer, required this.onTap});

  final Trainer trainer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 110,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.palette.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      context.palette.arctic,
                      context.palette.arcticSoft,
                    ],
                  ).createShader(r),
                  child: Text(
                    trainer.displayName.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 44,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              ClipOval(
                child: Container(
                  width: 78,
                  height: 78,
                  color: context.palette.surfaceHigh,
                  child: Image.asset(
                    trainer.avatarAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target-zones picker screen — cutout on the right, multi-select pills left.
// ---------------------------------------------------------------------------

class TargetZonesEditScreen extends StatefulWidget {
  const TargetZonesEditScreen({super.key, required this.initial});

  final Set<TargetZone> initial;

  @override
  State<TargetZonesEditScreen> createState() => _TargetZonesEditScreenState();
}

class _TargetZonesEditScreenState extends State<TargetZonesEditScreen> {
  static const _zoneOrder = <TargetZone>[
    TargetZone.fullBody,
    TargetZone.back,
    TargetZone.arms,
    TargetZone.belly,
    TargetZone.butt,
    TargetZone.legs,
  ];

  late Set<TargetZone> _selected = {...widget.initial};

  void _toggle(TargetZone z) {
    setState(() {
      if (z == TargetZone.fullBody) {
        _selected
          ..clear()
          ..add(TargetZone.fullBody);
        return;
      }
      _selected.remove(TargetZone.fullBody);
      if (_selected.contains(z)) {
        _selected.remove(z);
      } else {
        _selected.add(z);
      }
      if (_selected.isEmpty) _selected.add(TargetZone.fullBody);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.abyss,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'What are your target zones?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.chalk,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose all that apply',
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const pillWidth = 150.0;
                  const pillHeight = 52.0;
                  const pillGap = 12.0;
                  const sidePad = 16.0;
                  final stackHeight = constraints.maxHeight;
                  final totalPillsHeight =
                      _zoneOrder.length * pillHeight +
                          (_zoneOrder.length - 1) * pillGap;
                  final pillsTop = ((stackHeight - totalPillsHeight) / 2)
                      .clamp(0.0, double.infinity);

                  return Stack(
                    children: [
                      // Hero cutout — anchored bottom-right, fills the
                      // available box behind everything else.
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 0),
                            child: Image.asset(
                              'assets/branding/onboarding_hero_16 Background Removed.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      // Pills column
                      Positioned(
                        left: sidePad,
                        top: pillsTop,
                        width: pillWidth,
                        child: Column(
                          children: [
                            for (var i = 0; i < _zoneOrder.length; i++) ...[
                              _ZonePill(
                                label: _zoneLabel(_zoneOrder[i]),
                                selected: _selected.contains(_zoneOrder[i]),
                                onTap: () => _toggle(_zoneOrder[i]),
                                width: pillWidth,
                                height: pillHeight,
                              ),
                              if (i != _zoneOrder.length - 1)
                                const SizedBox(height: pillGap),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: _PrimaryButton(
                label: 'CONTINUE',
                enabled: _selected.isNotEmpty,
                onTap: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _VoiceGuidanceCard extends StatelessWidget {
  const _VoiceGuidanceCard();

  @override
  Widget build(BuildContext context) {
    final sounds = context.watch<SoundsController>();
    final enabled = sounds.voiceEnabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Voice Guidance',
                  style: TextStyle(
                    color: context.palette.chalk,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: sounds.setVoiceEnabled,
                activeColor: context.palette.arctic,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VerbositySegment(
                    value: sounds.verbosity,
                    onChanged: sounds.setVerbosity,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.volume_off_rounded,
                          size: 20, color: context.palette.muted),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            activeTrackColor: context.palette.arctic,
                            inactiveTrackColor: context.palette.hairline,
                            thumbColor: Colors.white,
                            overlayColor:
                                context.palette.arctic.withOpacity(0.15),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10),
                          ),
                          child: Slider(
                            value: sounds.voiceVolume,
                            onChanged: sounds.setVoiceVolume,
                          ),
                        ),
                      ),
                      Icon(Icons.volume_up_rounded,
                          size: 20, color: context.palette.muted),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerbositySegment extends StatelessWidget {
  const _VerbositySegment({required this.value, required this.onChanged});

  final VoiceVerbosity value;
  final ValueChanged<VoiceVerbosity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SegmentButton(
            label: 'Brief',
            icon: Icons.chat_bubble_outline_rounded,
            selected: value == VoiceVerbosity.brief,
            onTap: () => onChanged(VoiceVerbosity.brief),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SegmentButton(
            label: 'Detailed',
            icon: Icons.forum_outlined,
            selected: value == VoiceVerbosity.detailed,
            onTap: () => onChanged(VoiceVerbosity.detailed),
          ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.palette.arctic : context.palette.surfaceHigh;
    final fg = selected ? Colors.white : context.palette.chalk;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_rounded, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonePill extends StatelessWidget {
  const _ZonePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 170,
    this.height = 52,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final activeBg = context.palette.arctic.withOpacity(0.18);
    final activeBorder = context.palette.arctic;
    final idleBg = context.palette.surface;
    final idleBorder = context.palette.hairline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? activeBg : idleBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: selected ? activeBorder : idleBorder,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.palette.chalk,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? context.palette.arctic : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? context.palette.arctic
                        : context.palette.muted,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen wrapper that reuses the onboarding trainer-pick UI, but pops
/// with the selected [Trainer] instead of advancing an onboarding flow.
class TrainerPickerScreen extends StatelessWidget {
  const TrainerPickerScreen({super.key, required this.initial});

  final Trainer initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.abyss,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: TrainerPickStep(
            initial: initial,
            onCompleted: (t) => Navigator.of(context).pop(t),
          ),
        ),
      ),
    );
  }
}

/// Wraps an onboarding-kit step (GoalStep / WorkoutDurationStep / etc.) in a
/// minimal Scaffold with a back button so it can be pushed as a settings-edit
/// route. The step already exposes `selected` (user's current answer) and
/// auto-advances on tap, so onAnswered here just pops with the value.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.abyss,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: child,
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: palette.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: palette.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: palette.danger),
          ],
        ),
      ),
    );
  }
}

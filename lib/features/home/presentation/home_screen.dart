import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/core/theme/theme_controller.dart';
import 'package:military_calisthenics_women/features/custom_workout/application/custom_workout_builder.dart';
import 'package:military_calisthenics_women/features/custom_workout/application/custom_workouts_controller.dart';
import 'package:military_calisthenics_women/features/custom_workout/presentation/custom_filter_screen.dart';
import 'package:military_calisthenics_women/features/home/presentation/widgets/day_card.dart';
import 'package:military_calisthenics_women/features/home/presentation/widgets/squad_status_card.dart';
import 'package:military_calisthenics_women/features/home/presentation/widgets/stage_progress_rail.dart';
import 'package:military_calisthenics_women/features/home/presentation/workout_day_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:military_calisthenics_women/features/plan/presentation/edit_plan_screen.dart';
import 'package:military_calisthenics_women/features/profile/presentation/profile_screen.dart';
import 'package:military_calisthenics_women/features/workouts/application/progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/starred_workouts_controller.dart';
import 'package:military_calisthenics_women/features/workouts/presentation/mission_complete_modal.dart';
import 'package:military_calisthenics_women/features/workouts/presentation/training_screen.dart';
import 'package:provider/provider.dart';

/// First screen a paying user lands on after onboarding. Renders the 21-day
/// mission as a scrollable dossier: title → Squad Status card → per-stage
/// rail with day cards → bottom nav. Every day card taps through to
/// [WorkoutDayScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  /// Which day the user is currently on. Advances as they complete days —
  /// the next uncompleted day (capped at 21) is the active card.
  int _activeDayFor(ProgressController progress) {
    for (var d = 1; d <= 21; d++) {
      if (!progress.isDayCompleted(d)) return d;
    }
    return 21;
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingController>();
    final progress = context.watch<ProgressController>();
    final activeDay = _activeDayFor(progress);

    // If a workout just finished, surface the celebration modal once the
    // frame is on-screen. Guarded so it fires at most once per pending day.
    if (progress.pendingCelebrationDay != null) {
      final day = progress.pendingCelebrationDay!;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await MissionCompleteModal.show(
          context,
          dayIndex: day,
          starCount: progress.stars,
        );
        await context.read<ProgressController>().clearPendingCelebration();
      });
    }
    // Onboarding stores the generated plan in-memory. On a cold restart after
    // completing onboarding the answer map is empty, so fall back to a plan
    // regenerated from whatever inputs the controller still has (defaults
    // when nothing is present) rather than dead-ending on the fallback.
    final plan =
        onboarding.answerFor<Plan>('plan') ?? generatePlan(const PlanInputs());

    return Scaffold(
      backgroundColor: context.palette.abyss,
      body: SafeArea(
        bottom: false,
        child: switch (_navIndex) {
          1 => const TrainingScreen(),
          2 => _CustomTabBody(plan: plan),
          3 => const ProfileScreen(),
          _ => _MissionBody(plan: plan, activeDay: activeDay),
        },
      ),
      floatingActionButton: _navIndex == 2
          ? FloatingActionButton(
              backgroundColor: context.palette.arctic,
              foregroundColor: context.palette.chalk,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CustomFilterScreen(),
                ),
              ),
              child: const Icon(Icons.add, size: 30),
            )
          : null,
      bottomNavigationBar: _MissionNavBar(
        currentIndex: _navIndex,
        onSelected: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _MissionBody extends StatefulWidget {
  const _MissionBody({required this.plan, required this.activeDay});

  final Plan plan;
  final int activeDay;

  @override
  State<_MissionBody> createState() => _MissionBodyState();
}

class _MissionBodyState extends State<_MissionBody> {
  final GlobalKey _activeDayKey = GlobalKey();
  bool _didAutoScroll = false;

  Plan get plan => widget.plan;
  int get activeDay => widget.activeDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(covariant _MissionBody old) {
    super.didUpdateWidget(old);
    if (old.activeDay != widget.activeDay) {
      _didAutoScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (_didAutoScroll || !mounted) return;
    final ctx = _activeDayKey.currentContext;
    if (ctx == null) return;
    final render = ctx.findRenderObject();
    final scrollable = Scrollable.maybeOf(ctx);
    if (render == null || scrollable == null) return;
    final viewport = RenderAbstractViewport.of(render);
    final target = viewport
        .getOffsetToReveal(render, 0.0)
        .offset - _pinnedStageHeaderHeight;
    final position = scrollable.position;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _didAutoScroll = true;
    position.animateTo(
      clamped,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  // Matches the height of the pinned stage header (label + progress row +
  // 12px bottom padding). Kept in sync visually with _StageHeader.
  static const double _pinnedStageHeaderHeight = 40;

  @override
  Widget build(BuildContext context) {
    final activeStage = plan.stages.firstWhere(
      (s) => s.dayIndices.contains(activeDay),
      orElse: () => plan.stages.first,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: const _HeaderBlock(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SquadStatusCard(
            rank: _rankForDay(activeDay),
            stageIndex: activeStage.index,
            totalStages: plan.stages.length,
            starsEarned: _starsForDay(activeDay),
            starsTotal: 7,
          ),
        ),
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: _buildStageSlivers(context),
          ),
        ),
      ],
    );
  }

  /// Slivers for each stage: a pinned stage header (sticks to the top while
  /// its own day cards are on screen, then pushed away by the next stage's
  /// header) followed by that stage's day cards.
  List<Widget> _buildStageSlivers(BuildContext context) {
    final slivers = <Widget>[];
    for (var s = 0; s < plan.stages.length; s++) {
      final stage = plan.stages[s];
      final stageDays = plan.days
          .where((d) => stage.dayIndices.contains(d.dayIndex))
          .toList(growable: false);
      final dayItems = <Widget>[];
      for (var i = 0; i < stageDays.length; i++) {
        final day = stageDays[i];
        final isActive = day.dayIndex == activeDay;
        dayItems.add(Padding(
          key: isActive ? _activeDayKey : null,
          padding: const EdgeInsets.only(bottom: 14),
          child: StageProgressRail(
            isFirst: i == 0,
            isLast: i == stageDays.length - 1,
            isActive: isActive,
            isCompleted: day.dayIndex < activeDay,
            child: DayCard(
              day: day,
              isActive: isActive,
              isCompleted: day.dayIndex < activeDay,
              onTap: () {
                if (day.dayIndex > activeDay) {
                  _showLockedDaySheet(context);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutDayScreen(day: day),
                    ),
                  );
                }
              },
            ),
          ),
        ));
      }
      slivers.add(SliverMainAxisGroup(slivers: [
        PinnedHeaderSliver(
          child: Container(
            color: context.palette.abyss,
            padding: EdgeInsets.fromLTRB(20, s == 0 ? 0 : 10, 20, 12),
            child: _StageHeader(
              stage: stage,
              progress: _stageProgress(stage, activeDay),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverList.list(children: dayItems),
        ),
      ]));
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
    return slivers;
  }

  static String _rankForDay(int day) {
    // 21-day mission split across all seven ranks, ~3 days per promotion.
    // Extra days at the top so a full completion crowns the user General.
    if (day >= 21) return 'GENERAL';
    if (day >= 18) return 'CAPTAIN';
    if (day >= 15) return 'LIEUTENANT';
    if (day >= 12) return 'SERGEANT';
    if (day >= 9) return 'CORPORAL';
    if (day >= 5) return 'PRIVATE';
    return 'RECRUIT';
  }

  static int _starsForDay(int day) {
    // One gold star per rank tier reached. Ramp mirrors [_rankForDay] so the
    // star count and the badge always agree — Recruit=1 … General=7.
    if (day >= 21) return 7;
    if (day >= 18) return 6;
    if (day >= 15) return 5;
    if (day >= 12) return 4;
    if (day >= 9) return 3;
    if (day >= 5) return 2;
    return 1;
  }

  static double _stageProgress(PlanStage stage, int activeDay) {
    if (activeDay < stage.dayIndices.first) return 0.0;
    if (activeDay > stage.dayIndices.last) return 1.0;
    final done = activeDay - stage.dayIndices.first;
    return done / stage.dayIndices.length;
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _ThemeToggleButton(),
        const Spacer(),
        _EditButton(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditPlanScreen()),
          ),
        ),
      ],
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final mode = controller.themeMode;
    final label = switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Auto',
    };
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final next = switch (mode) {
            ThemeMode.system => ThemeMode.light,
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => ThemeMode.system,
          };
          controller.setThemeMode(next);
        },
        child: Tooltip(
          message: 'Theme: $label (tap to change)',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _ThemeGlyph(mode: mode, color: context.palette.chalk),
          ),
        ),
      ),
    );
  }
}

/// Compact theme-mode glyph. Auto = plain circle around an "A"; Light/Dark
/// keep their standard sun/moon icons. The Auto glyph is drawn from scratch
/// because Material's `brightness_auto` icon is a jagged star shape.
class _ThemeGlyph extends StatelessWidget {
  const _ThemeGlyph({required this.mode, required this.color});

  final ThemeMode mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (mode != ThemeMode.system) {
      return Icon(
        mode == ThemeMode.light
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
        size: 18,
        color: color,
      );
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.6),
        ),
        child: Center(
          child: Text(
            'A',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_outlined,
                  size: 16, color: context.palette.chalk),
              const SizedBox(width: 6),
              Text(
                'Settings',
                style: TextStyle(
                  color: context.palette.chalk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage, required this.progress});

  final PlanStage stage;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            stage.title,
            style: TextStyle(
              color: context.palette.mist,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 90,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: context.palette.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.palette.arctic,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).round()}%',
          style: GoogleFonts.plusJakartaSans(
            color: context.palette.mist,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MissionNavBar extends StatelessWidget {
  const _MissionNavBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _items = <_NavItem>[
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Training'),
    _NavItem(icon: Icons.auto_awesome_rounded, label: 'Custom'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.midnight,
        border: Border(top: BorderSide(color: context.palette.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavCell(
                  item: _items[i],
                  isActive: currentIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? context.palette.arctic : context.palette.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? context.palette.surface.withOpacity(0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Custom tab body. Currently just surfaces the workouts the user has starred
/// from the workout-day screen. Wire additional custom-workout tools in here
/// as they ship — each becomes its own section under the header.
class _CustomTabBody extends StatelessWidget {
  const _CustomTabBody({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StarredWorkoutsController>();
    final customs = context.watch<CustomWorkoutsController>().specs;
    final starredDays = plan.days.where((d) {
      final key = StarredWorkoutsController.keyFor(
          dayIndex: d.dayIndex, title: d.title);
      return controller.isStarred(key);
    }).toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Center(
              child: Text(
                'Custom',
                style: GoogleFonts.plusJakartaSans(
                  color: context.palette.chalk,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded,
                    size: 18, color: context.palette.danger),
                const SizedBox(width: 8),
                Text(
                  'Starred',
                  style: TextStyle(
                    color: context.palette.chalk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${starredDays.length}',
                  style: TextStyle(
                    color: context.palette.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (starredDays.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.palette.hairline),
                ),
                child: Text(
                  'Tap the heart on any workout to save it here for quick '
                  'access.',
                  style: TextStyle(
                    color: context.palette.mist,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            sliver: SliverList.list(
              children: [
                for (final day in starredDays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StarredDayTile(day: day),
                  ),
              ],
            ),
          ),
        if (customs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 18, color: context.palette.arctic),
                  const SizedBox(width: 8),
                  Text(
                    'Custom',
                    style: TextStyle(
                      color: context.palette.chalk,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${customs.length}',
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24 + 88),
            sliver: SliverList.list(
              children: [
                for (final spec in customs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CustomWorkoutTile(spec: spec),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CustomWorkoutTile extends StatelessWidget {
  const _CustomWorkoutTile({required this.spec});

  final CustomWorkoutSpec spec;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final day = spec.build();
    final minutes = day?.estimatedMinutes ?? 0;
    final kcal = day?.estimatedCalories ?? 0;
    final heroAsset = spec.areas.isEmpty
        ? 'assets/branding/custom_background.png'
        : spec.areas.first.asset;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: day == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WorkoutDayScreen(day: day)),
                ),
        onLongPress: () => _confirmDelete(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Image.asset(
                    heroAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: palette.surfaceHigh),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spec.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: palette.chalk,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MetaChip(label: '$minutes Mins', color: palette.arctic),
                        const SizedBox(width: 8),
                        _MetaChip(
                            label: '$kcal Kcal', color: palette.arcticDeep),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.midnight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete this custom workout?',
                style: TextStyle(
                  color: sheetCtx.palette.chalk,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: sheetCtx.palette.danger,
                  ),
                  onPressed: () {
                    sheetCtx
                        .read<CustomWorkoutsController>()
                        .remove(spec.id);
                    Navigator.of(sheetCtx).pop();
                  },
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.palette.chalk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StarredDayTile extends StatelessWidget {
  const _StarredDayTile({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WorkoutDayScreen(day: day)),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: context.palette.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.fitness_center_rounded,
                    color: context.palette.arctic, size: 40),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      day.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: context.palette.chalk,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MetaChip(
                            label: '${day.estimatedMinutes} Mins',
                            color: context.palette.arctic),
                        const SizedBox(width: 8),
                        _MetaChip(
                            label: '${day.estimatedCalories} Kcal',
                            color: context.palette.arcticDeep),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showLockedDaySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.midnight,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetCtx.palette.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Step by Step',
                style: TextStyle(
                  color: sheetCtx.palette.chalk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'This practice will be available after you finish the '
                'previous day in the plan. You can pick some other class '
                'if you want to do more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sheetCtx.palette.mist,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: const Text('GOT IT'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

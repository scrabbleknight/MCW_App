import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/home/presentation/widgets/day_card.dart';
import 'package:military_calisthenics_women/features/home/presentation/widgets/squad_status_card.dart';
import 'package:military_calisthenics_women/features/home/presentation/widgets/stage_progress_rail.dart';
import 'package:military_calisthenics_women/features/home/presentation/workout_day_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
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

  /// Which day the user is currently on. Wire this to a real progress store
  /// later — for now the mission always starts on Day 1 so the CTA lights up
  /// the first card.
  int get _activeDay => 1;

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingController>();
    final plan = onboarding.answerFor<Plan>('plan');

    return Scaffold(
      backgroundColor: TacticalPalette.abyss,
      body: SafeArea(
        bottom: false,
        child: plan == null
            ? const _NoPlanFallback()
            : _MissionBody(plan: plan, activeDay: _activeDay),
      ),
      bottomNavigationBar: _MissionNavBar(
        currentIndex: _navIndex,
        onSelected: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _MissionBody extends StatelessWidget {
  const _MissionBody({required this.plan, required this.activeDay});

  final Plan plan;
  final int activeDay;

  @override
  Widget build(BuildContext context) {
    final activeStage = plan.stages.firstWhere(
      (s) => s.dayIndices.contains(activeDay),
      orElse: () => plan.stages.first,
    );
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: _HeaderBlock(plan: plan),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SquadStatusCard(
              rank: _rankForDay(activeDay),
              stageIndex: activeStage.index,
              totalStages: plan.stages.length,
              starsEarned: _starsForDay(activeDay),
              starsTotal: 7,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList.list(
            children: _buildStageSections(context),
          ),
        ),
      ],
    );
  }

  /// Flat list of stage headers and day cards. Each stage renders its own
  /// header (title + progress %) followed by its 7 day cards. The vertical
  /// progress rail restarts inside each stage so the visual break is clean.
  List<Widget> _buildStageSections(BuildContext context) {
    final items = <Widget>[];
    for (var s = 0; s < plan.stages.length; s++) {
      final stage = plan.stages[s];
      final stageDays = plan.days
          .where((d) => stage.dayIndices.contains(d.dayIndex))
          .toList(growable: false);
      items.add(Padding(
        padding: EdgeInsets.fromLTRB(0, s == 0 ? 0 : 10, 0, 12),
        child: _StageHeader(
          stage: stage,
          progress: _stageProgress(stage, activeDay),
        ),
      ));
      for (var i = 0; i < stageDays.length; i++) {
        final day = stageDays[i];
        final isActive = day.dayIndex == activeDay;
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: StageProgressRail(
            isFirst: i == 0,
            isLast: i == stageDays.length - 1,
            isActive: isActive,
            isCompleted: day.dayIndex < activeDay,
            child: DayCard(
              day: day,
              isActive: isActive,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkoutDayScreen(day: day),
                ),
              ),
            ),
          ),
        ));
      }
    }
    return items;
  }

  static String _rankForDay(int day) {
    if (day >= 15) return 'SERGEANT';
    if (day >= 8) return 'CORPORAL';
    return 'CADET';
  }

  static int _starsForDay(int day) {
    // Simple ramp during Stage 1 for the star row on the status card.
    return (day - 1).clamp(0, 7);
  }

  static double _stageProgress(PlanStage stage, int activeDay) {
    if (activeDay < stage.dayIndices.first) return 0.0;
    if (activeDay > stage.dayIndices.last) return 1.0;
    final done = activeDay - stage.dayIndices.first;
    return done / stage.dayIndices.length;
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.durationDays} DAYS',
                style: GoogleFonts.jetBrainsMono(
                  color: TacticalPalette.arcticSoft,
                  letterSpacing: 2.4,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                plan.title,
                style: GoogleFonts.bigShouldersDisplay(
                  color: TacticalPalette.chalk,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                  height: 1.0,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        _EditButton(onTap: () {}),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TacticalPalette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined,
                  size: 16, color: TacticalPalette.chalk),
              const SizedBox(width: 6),
              Text(
                'Edit',
                style: TextStyle(
                  color: TacticalPalette.chalk,
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
            style: const TextStyle(
              color: TacticalPalette.mist,
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
                  backgroundColor: TacticalPalette.surfaceHigh,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    TacticalPalette.arctic,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).round()}%',
          style: GoogleFonts.jetBrainsMono(
            color: TacticalPalette.mist,
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
    _NavItem(icon: Icons.bolt_rounded, label: 'Today'),
    _NavItem(icon: Icons.explore_outlined, label: 'Training'),
    _NavItem(icon: Icons.dashboard_customize_outlined, label: 'Custom'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TacticalPalette.midnight,
        border: Border(top: BorderSide(color: TacticalPalette.hairline)),
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
        isActive ? TacticalPalette.arctic : TacticalPalette.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? TacticalPalette.surface.withOpacity(0.8)
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

class _NoPlanFallback extends StatelessWidget {
  const _NoPlanFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No mission on file. Redo the calibration step to generate '
          "today's briefing.",
          textAlign: TextAlign.center,
          style: TextStyle(color: TacticalPalette.mist, fontSize: 15),
        ),
      ),
    );
  }
}

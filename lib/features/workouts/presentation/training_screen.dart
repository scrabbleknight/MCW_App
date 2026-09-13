import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/workouts/application/training_progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/domain/training_catalogue.dart';
import 'package:military_calisthenics_women/features/home/presentation/workout_day_screen.dart';
import 'package:provider/provider.dart';

/// Training tab body. Renders a scrollable dossier of named ops categories,
/// each with a horizontal rail of 5 mission cards. Every card is a day-length
/// routine — tap-through to the session screen is a follow-up.
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  static const List<_TrainingCategory> _categories = [
    _TrainingCategory(
      title: 'Trending',
      key: TrainingCategoryKey.trending,
      routines: [
        _Routine(
          name: 'Summer Ready Burn',
          level: 'Intermediate',
          minutes: 14,
          kcal: 138,
          imageAsset: 'assets/branding/summer_ready_burn.png',
        ),
        _Routine(
          name: 'Sunrise Assault',
          level: 'Beginner',
          minutes: 10,
          kcal: 92,
          imageAsset: 'assets/branding/sunrise_assault.png',
        ),
        _Routine(
          name: 'HIIT Blackout',
          level: 'Advanced',
          minutes: 18,
          kcal: 210,
          imageAsset: 'assets/branding/hiit_blackout.png',
        ),
        _Routine(
          name: 'Deck of Cards',
          level: 'Intermediate',
          minutes: 20,
          kcal: 185,
          imageAsset: 'assets/branding/deck_of_cards.png',
        ),
        _Routine(
          name: 'Quick Deploy',
          level: 'Beginner',
          minutes: 8,
          kcal: 74,
          imageAsset: 'assets/branding/quick_deploy.png',
        ),
      ],
    ),
    _TrainingCategory(
      title: 'Combat Conditioning',
      key: TrainingCategoryKey.combatConditioning,
      routines: [
        _Routine(
          name: 'Full Body Drill',
          level: 'Beginner',
          minutes: 9,
          kcal: 101,
          imageAsset: 'assets/branding/full_body_drill.png',
        ),
        _Routine(
          name: 'Foxtrot Fat Torch',
          level: 'Intermediate',
          minutes: 15,
          kcal: 160,
          imageAsset: 'assets/branding/foxtrot_fat_torch.png',
        ),
        _Routine(
          name: 'Zero Gear Grinder',
          level: 'Advanced',
          minutes: 22,
          kcal: 240,
          imageAsset: 'assets/branding/zero_gear_grinder.png',
        ),
        _Routine(
          name: 'Rapid Reveille',
          level: 'Beginner',
          minutes: 12,
          kcal: 118,
          imageAsset: 'assets/branding/rapid_reveille.png',
        ),
        _Routine(
          name: 'Bunker Blast',
          level: 'Intermediate',
          minutes: 16,
          kcal: 172,
          imageAsset: 'assets/branding/bunker_blast.png',
        ),
      ],
    ),
    _TrainingCategory(
      title: 'Battle-Ready Strength',
      key: TrainingCategoryKey.battleReadyStrength,
      routines: [
        _Routine(
          name: 'Combat Body Burn',
          level: 'Intermediate',
          minutes: 11,
          kcal: 117,
          imageAsset: 'assets/branding/combat_body_burn.png',
        ),
        _Routine(
          name: 'Iron Squad Sculpt',
          level: 'Advanced',
          minutes: 20,
          kcal: 205,
          imageAsset: 'assets/branding/iron_squad_sculpt.png',
        ),
        _Routine(
          name: 'Bootcamp Bulk',
          level: 'Intermediate',
          minutes: 18,
          kcal: 190,
          imageAsset: 'assets/branding/bootcamp_bulk.png',
        ),
        _Routine(
          name: 'Steel Core Run',
          level: 'Beginner',
          minutes: 10,
          kcal: 96,
          imageAsset: 'assets/branding/steel_core_run.png',
        ),
        _Routine(
          name: 'Trench Push',
          level: 'Advanced',
          minutes: 24,
          kcal: 260,
          imageAsset: 'assets/branding/trench_push.png',
        ),
      ],
    ),
    _TrainingCategory(
      title: 'Recon Recovery',
      key: TrainingCategoryKey.reconRecovery,
      routines: [
        _Routine(
          name: 'Lower Body Reset',
          level: 'Beginner',
          minutes: 12,
          kcal: 120,
          imageAsset: 'assets/branding/lower_body_reset.png',
        ),
        _Routine(
          name: 'Upper Body Unlock',
          level: 'Beginner',
          minutes: 10,
          kcal: 88,
          imageAsset: 'assets/branding/upper_body_unlock.png',
        ),
        _Routine(
          name: 'Silent March Stretch',
          level: 'Beginner',
          minutes: 14,
          kcal: 110,
          imageAsset: 'assets/branding/silent_march_stretch.png',
        ),
        _Routine(
          name: 'Hip Sweep Flow',
          level: 'Intermediate',
          minutes: 16,
          kcal: 135,
          imageAsset: 'assets/branding/hip_sweep_flow.png',
        ),
        _Routine(
          name: 'Cooldown Perimeter',
          level: 'Beginner',
          minutes: 8,
          kcal: 60,
          imageAsset: 'assets/branding/cooldown_perimeter.png',
        ),
      ],
    ),
    _TrainingCategory(
      title: 'Low-Impact Ops',
      key: TrainingCategoryKey.lowImpactOps,
      routines: [
        _Routine(
          name: 'Knee-Safe Patrol',
          level: 'Beginner',
          minutes: 12,
          kcal: 100,
          imageAsset: 'assets/branding/knee_safe_patrol.png',
        ),
        _Routine(
          name: 'Silent Steps',
          level: 'Beginner',
          minutes: 10,
          kcal: 82,
          imageAsset: 'assets/branding/silent_steps.png',
        ),
        _Routine(
          name: 'Standing Stealth',
          level: 'Beginner',
          minutes: 14,
          kcal: 118,
          imageAsset: 'assets/branding/standing_stealth.png',
        ),
        _Routine(
          name: 'Gentle Recon',
          level: 'Beginner',
          minutes: 16,
          kcal: 130,
          imageAsset: 'assets/branding/gentle_recon.png',
        ),
        _Routine(
          name: 'Ground Guard',
          level: 'Intermediate',
          minutes: 18,
          kcal: 152,
          imageAsset: 'assets/branding/ground_guard.png',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Center(
              child: Text(
                'Training',
                style: GoogleFonts.plusJakartaSans(
                  color: context.palette.chalk,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < _categories.length; i++)
          SliverToBoxAdapter(
            child: _CategorySection(category: _categories[i], accentIndex: i),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _TrainingCategory {
  const _TrainingCategory({
    required this.title,
    required this.key,
    required this.routines,
  });
  final String title;
  final TrainingCategoryKey key;
  final List<_Routine> routines;
}

class _Routine {
  const _Routine({
    required this.name,
    required this.level,
    required this.minutes,
    required this.kcal,
    this.imageAsset,
  });
  final String name;
  final String level;
  final int minutes;
  final int kcal;
  final String? imageAsset;
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.accentIndex});

  final _TrainingCategory category;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.palette.chalk,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _TrainingCategoryScreen(
                        category: category,
                        accentIndex: accentIndex,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.palette.muted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: category.routines.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => _RoutineCard(
                routine: category.routines[i],
                categoryKey: category.key,
                accentIndex: accentIndex,
                slot: i,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.categoryKey,
    required this.accentIndex,
    required this.slot,
    this.width = 300,
    this.height = 220,
  });

  final _Routine routine;
  final TrainingCategoryKey categoryKey;
  final int accentIndex;
  final int slot;
  final double width;
  final double height;

  void _open(BuildContext context) {
    final day = buildTrainingDay(
      category: categoryKey,
      slot: slot,
      name: routine.name,
      minutes: routine.minutes,
      kcal: routine.kcal,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WorkoutDayScreen(day: day, heroImageAsset: routine.imageAsset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = context.watch<TrainingProgressController>().percentFor(
      trainingDayKey(categoryKey, slot),
    );
    final inProgress = percent > 0 && percent < 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _RoutineImage(
              imageAsset: routine.imageAsset,
              accentIndex: accentIndex,
              slot: slot,
            ),
            // Bottom gradient scrim so the title/chips stay legible.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    routine.name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (inProgress)
                    _ContinueBar(
                      percent: percent,
                      onContinue: () => _open(context),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(text: routine.level),
                        _Chip(text: '${routine.minutes} Mins'),
                        _Chip(text: '${routine.kcal} Kcal'),
                      ],
                    ),
                ],
              ),
            ),
            // Card-wide tap target — suppressed when the in-progress bar is
            // showing so the CONTINUE button gets the tap instead.
            if (!inProgress)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: () => _open(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// In-progress bottom strip — replaces the chip row when the user has
/// started but not finished a training routine. Shows "{n}% completed" plus
/// a linear progress bar on the left and a filled CONTINUE pill on the
/// right. Tap-through goes back to the same detail screen the card opens.
class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.percent, required this.onContinue});

  final int percent;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent% completed',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onContinue,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                'CONTINUE',
                style: GoogleFonts.plusJakartaSans(
                  color: context.palette.arcticDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Full-screen "See All" view for one category — a vertical list of the
/// same routine cards blown up to fill the width. Reuses [_RoutineCard] so
/// tap-through behaviour and visuals stay in sync with the Training tab.
class _TrainingCategoryScreen extends StatelessWidget {
  const _TrainingCategoryScreen({
    required this.category,
    required this.accentIndex,
  });

  final _TrainingCategory category;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.abyss,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: context.palette.chalk,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        category.title,
                        style: GoogleFonts.plusJakartaSans(
                          color: context.palette.chalk,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: category.routines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) => _RoutineCard(
                  routine: category.routines[i],
                  categoryKey: category.key,
                  accentIndex: accentIndex,
                  slot: i,
                  width: double.infinity,
                  height: 240,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineImage extends StatelessWidget {
  const _RoutineImage({
    required this.imageAsset,
    required this.accentIndex,
    required this.slot,
  });

  final String? imageAsset;
  final int accentIndex;
  final int slot;

  static const List<List<Color>> _palettes = [
    [Color(0xFF1D5FD1), Color(0xFF6FA8DC)],
    [Color(0xFF2C3E50), Color(0xFF4A6572)],
    [Color(0xFF3A1C71), Color(0xFF5B4B8A)],
    [Color(0xFF134E5E), Color(0xFF71B280)],
    [Color(0xFF4B3F72), Color(0xFF7E6B94)],
  ];

  static const List<IconData> _icons = [
    Icons.local_fire_department_rounded,
    Icons.fitness_center_rounded,
    Icons.sports_martial_arts_rounded,
    Icons.self_improvement_rounded,
    Icons.directions_walk_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: const Alignment(-0.72, 0),
      );
    }

    final colors = _palettes[accentIndex % _palettes.length];
    final icon = _icons[accentIndex % _icons.length];
    // Slot nudges the gradient angle so cards in one row don't look identical.
    final align = Alignment(-1 + (slot * 0.3), -1 + (slot * 0.15));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: align,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Icon(icon, size: 180, color: Colors.white.withOpacity(0.08)),
          ),
        ],
      ),
    );
  }
}

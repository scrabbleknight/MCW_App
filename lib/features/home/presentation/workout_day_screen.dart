import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise_lookup.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// Detail view for one day of the mission — Duration / Calories / Target
/// Muscle summary cards up top, then the three phased exercise lists and a
/// sticky START button. Skeleton uses placeholder tiles for every exercise
/// image so the layout is complete before the real thumbnails ship.
class WorkoutDayScreen extends StatelessWidget {
  const WorkoutDayScreen({super.key, required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TacticalPalette.abyss,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Hero(day: day)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                day.title,
                style: GoogleFonts.bigShouldersDisplay(
                  color: TacticalPalette.chalk,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
            sliver: SliverToBoxAdapter(child: _SummaryRow(day: day)),
          ),
          _PhaseSection(
            label: 'Warm up',
            blocks: day.warmup,
          ),
          _PhaseSection(
            label: 'Main',
            blocks: day.main,
          ),
          _PhaseSection(
            label: 'Cool down',
            blocks: day.cooldown,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _StartButton(onTap: () {}),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder blue-camo hero — swap for the real photo per day
          // once workout thumbnails ship.
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  TacticalPalette.arcticDeep,
                  TacticalPalette.midnight,
                ],
              ),
            ),
          ),
          const Center(
            child: Opacity(
              opacity: 0.25,
              child: Icon(
                Icons.fitness_center_rounded,
                color: TacticalPalette.chalk,
                size: 96,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    TacticalPalette.abyss.withOpacity(0.85),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _CircleButton(icon: Icons.chevron_left_rounded, back: true),
                  Row(
                    children: [
                      _CircleButton(icon: Icons.music_note_rounded),
                      SizedBox(width: 8),
                      _CircleButton(icon: Icons.favorite_border_rounded),
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.back = false});

  final IconData icon;
  final bool back;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TacticalPalette.surface.withOpacity(0.7),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: back ? () => Navigator.of(context).maybePop() : () {},
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: TacticalPalette.chalk, size: 22),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    // Two-column grid matching the reference. Card height is fixed so the
    // muscle card's inner Column (label / body-map / toggle) has a bounded
    // parent to lay out against, and the left column's stat tiles stretch
    // to the same total via Expanded.
    const cardHeight = 220.0;
    return SizedBox(
      height: cardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Duration',
                    value: '${day.estimatedMinutes} mins',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Calories',
                    value: '${day.estimatedCalories} kcal',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: _TargetMuscleCard(day: day)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 4),
      decoration: BoxDecoration(
        color: TacticalPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TacticalPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: TacticalPalette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bigShouldersDisplay(
              color: TacticalPalette.chalk,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Muscle-target card that mirrors the reference layout: label + focus name
/// on the left, a big body-map render on the right, Front/Back segmented
/// toggle underneath. The body-map asset is picked from
/// [_muscleMapAsset] — each day's title maps to a specific overlay, with
/// [skeleton.png] as a graceful fallback until the per-day maps ship.
class _TargetMuscleCard extends StatefulWidget {
  const _TargetMuscleCard({required this.day});

  final PlanDay day;

  @override
  State<_TargetMuscleCard> createState() => _TargetMuscleCardState();
}

class _TargetMuscleCardState extends State<_TargetMuscleCard> {
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TacticalPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TacticalPalette.hairline),
      ),
      // Card is a vertical stack — label on top, big body-map filling the
      // middle, Front/Back toggle pinned to the bottom. Layout no longer
      // depends on the outer flex balance so it can't overflow the row.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Muscle',
            style: TextStyle(
              color: TacticalPalette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _targetMuscleLabel(widget.day.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.bigShouldersDisplay(
              color: TacticalPalette.chalk,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _MuscleMap(day: widget.day, showBack: _showBack),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _FrontBackToggle(
              showBack: _showBack,
              onChanged: (b) => setState(() => _showBack = b),
            ),
          ),
        ],
      ),
    );
  }

  static String _targetMuscleLabel(String title) {
    if (title.contains('Upper')) return 'Upper + Core';
    if (title.contains('Lower')) return 'Lower + Glutes';
    if (title.contains('Core')) return 'Core';
    return 'Full Body';
  }
}

/// Small segmented control between Front / Back views of the body map.
/// Styled to match the arctic accent — the selected pill glows softly.
class _FrontBackToggle extends StatelessWidget {
  const _FrontBackToggle({required this.showBack, required this.onChanged});

  final bool showBack;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TacticalPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            label: 'Front',
            selected: !showBack,
            onTap: () => onChanged(false),
          ),
          _Pill(
            label: 'Back',
            selected: showBack,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? TacticalPalette.arctic : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? TacticalPalette.chalk : TacticalPalette.mist,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Body map. Renders a base skeleton and stacks one transparent overlay
/// per muscle group the day targets. Files follow the
/// `skeleton_{muscle}_{front|back}.png` convention so the same muscle asset
/// can be reused across any day whose focus lights it up. Missing files
/// vanish silently — supply as many or as few as you want at any point.
class _MuscleMap extends StatelessWidget {
  const _MuscleMap({required this.day, required this.showBack});

  final PlanDay day;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final side = showBack ? 'back' : 'front';
    final muscles = _musclesFor(day.title, showBack: showBack);
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        // Neutral base outline. Prefer the side-specific skeleton once
        // supplied; otherwise fall back to the shared `skeleton.png`.
        Image.asset(
          'assets/branding/skeleton_base_$side.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/branding/skeleton.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            color: TacticalPalette.mist.withOpacity(0.75),
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
        // Layer each targeted muscle. Files that don't exist yet just
        // return SizedBox.shrink() so the base skeleton stays intact.
        for (final m in muscles)
          Image.asset(
            'assets/branding/skeleton_${m}_$side.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// Day title → list of muscle groups lit up on the map. Front vs back
/// swaps the group set (glutes only render from the back, chest only from
/// the front, etc.) so each side reads correctly on the toggle. Slugs
/// match the `assets/branding/skeleton_<slug>_<side>.png` files.
List<String> _musclesFor(String title, {required bool showBack}) {
  if (title.contains('Upper')) {
    return showBack
        ? const ['upper_back', 'shoulders', 'arms', 'obliques']
        : const ['chest', 'shoulders', 'arms', 'core', 'obliques'];
  }
  if (title.contains('Lower')) {
    return showBack
        ? const ['glutes', 'hamstrings', 'calves']
        : const ['quads', 'inner_thighs', 'calves'];
  }
  if (title.contains('Core')) {
    return showBack
        ? const ['lower_back', 'obliques']
        : const ['core', 'obliques'];
  }
  // Total Body / Full Body Cardio — everything.
  return showBack
      ? const [
          'upper_back',
          'shoulders',
          'arms',
          'lower_back',
          'glutes',
          'hamstrings',
          'calves',
        ]
      : const [
          'chest',
          'shoulders',
          'arms',
          'core',
          'obliques',
          'quads',
          'inner_thighs',
          'calves',
        ];
}

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({required this.label, required this.blocks});

  final String label;
  final List<PlanBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverList.list(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: GoogleFonts.bigShouldersDisplay(
                      color: TacticalPalette.chalk,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextSpan(
                    text: '${blocks.length} Exercises',
                    style: GoogleFonts.bigShouldersDisplay(
                      color: TacticalPalette.arctic,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final block in blocks) _ExerciseRow(block: block),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.block});

  final PlanBlock block;

  @override
  Widget build(BuildContext context) {
    final ex = findExercise(block.exerciseId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _ExerciseThumb(seed: block.exerciseId.hashCode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex?.name ?? block.exerciseId,
                  style: const TextStyle(
                    color: TacticalPalette.chalk,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _prescriptionLabel(block),
                  style: TextStyle(
                    color: TacticalPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _prescriptionLabel(PlanBlock block) {
    final unit =
        block.unit == ExerciseUnit.seconds ? '${block.amount}s' : '${block.amount} reps';
    if (block.sets <= 1) return unit;
    return '${block.sets} × $unit';
  }
}

class _ExerciseThumb extends StatelessWidget {
  const _ExerciseThumb({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final variants = <List<Color>>[
      [TacticalPalette.surfaceHigh, TacticalPalette.surface],
      [TacticalPalette.arcticDeep, TacticalPalette.midnight],
      [TacticalPalette.arctic, TacticalPalette.arcticDeep],
    ];
    final colors = variants[seed.abs() % variants.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.play_arrow_rounded,
            color: TacticalPalette.chalk,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  TacticalPalette.arcticDeep,
                  TacticalPalette.arctic,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: TacticalPalette.arctic.withOpacity(0.5),
                  blurRadius: 18,
                ),
              ],
              border: Border.all(
                color: TacticalPalette.glacier.withOpacity(0.6),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'START',
              style: GoogleFonts.bigShouldersDisplay(
                color: TacticalPalette.chalk,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

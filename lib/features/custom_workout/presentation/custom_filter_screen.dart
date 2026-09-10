import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/custom_workout/application/custom_workout_builder.dart';
import 'package:military_calisthenics_women/features/custom_workout/application/custom_workouts_controller.dart';
import 'package:military_calisthenics_women/features/home/presentation/workout_day_screen.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:provider/provider.dart';

/// Custom Exercise Filter — user picks a difficulty (single), one or more
/// focus areas, and one or more starting positions. Continue builds a
/// bespoke workout day and opens the standard workout-detail screen.
class CustomFilterScreen extends StatefulWidget {
  const CustomFilterScreen({super.key});

  @override
  State<CustomFilterScreen> createState() => _CustomFilterScreenState();
}

class _CustomFilterScreenState extends State<CustomFilterScreen> {
  ExerciseDifficulty _level = ExerciseDifficulty.intermediate;
  final Set<FocusArea> _areas = <FocusArea>{};
  final Set<PositionGroup> _positions = <PositionGroup>{};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.abyss,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(child: _SectionTitle('Level')),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LevelRow(
                    value: _level,
                    onChanged: (v) => setState(() => _level = v),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(child: _SectionTitle('Focus Area')),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: FocusArea.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final area = FocusArea.values[i];
                      return _FocusAreaChip(
                        area: area,
                        selected: _areas.contains(area),
                        onTap: () => setState(() {
                          if (!_areas.add(area)) _areas.remove(area);
                        }),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(child: _SectionTitle('Position')),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final p in PositionGroup.values)
                        _PositionChip(
                          label: p.label,
                          selected: _positions.contains(p),
                          onTap: () => setState(() {
                            if (!_positions.add(p)) _positions.remove(p);
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ContinueBar(onTap: _onContinue),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _BackButton(),
          ),
        ],
      ),
    );
  }

  void _onContinue() {
    final day = buildCustomWorkoutDay(
      level: _level,
      areas: _areas,
      positions: _positions,
    );
    if (day == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pick at least one focus area and one position to build a workout.',
          ),
        ),
      );
      return;
    }
    final spec = CustomWorkoutSpec(
      id: 'cw-${DateTime.now().microsecondsSinceEpoch}',
      title: day.title,
      level: _level,
      areas: {..._areas},
      positions: {..._positions},
    );
    context.read<CustomWorkoutsController>().add(spec);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WorkoutDayScreen(day: day)),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Image.asset(
            'assets/branding/custom_background.png',
            fit: BoxFit.fitWidth,
            width: double.infinity,
          ),
          Positioned.fill(child: _HeroFade()),
        ],
      ),
    );
  }
}

class _HeroFade extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              context.palette.abyss.withValues(alpha: 0.85),
              context.palette.abyss,
            ],
            stops: const [0.7, 0.94, 1.0],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.chevron_left,
              color: context.palette.chalk, size: 26),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: context.palette.chalk,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.value, required this.onChanged});
  final ExerciseDifficulty value;
  final ValueChanged<ExerciseDifficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final d in ExerciseDifficulty.values) ...[
          Expanded(
            child: _LevelCard(
              level: d,
              selected: value == d,
              onTap: () => onChanged(d),
            ),
          ),
          if (d != ExerciseDifficulty.values.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });
  final ExerciseDifficulty level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.arctic;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : palette.hairline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              _LevelDots(level: level, color: accent),
              const SizedBox(height: 10),
              Text(
                level.label,
                style: TextStyle(
                  color: selected ? accent : palette.mist,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelDots extends StatelessWidget {
  const _LevelDots({required this.level, required this.color});
  final ExerciseDifficulty level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = switch (level) {
      ExerciseDifficulty.beginner => 1,
      ExerciseDifficulty.intermediate => 2,
      ExerciseDifficulty.advanced => 3,
    };
    Widget dot(bool solid) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.4),
          ),
        );
    return SizedBox(
      width: 30,
      height: 22,
      child: Stack(
        children: [
          Positioned(left: 11, top: 0, child: dot(filled >= 3)),
          Positioned(left: 0, bottom: 0, child: dot(filled >= 2)),
          Positioned(right: 0, bottom: 0, child: dot(filled >= 1)),
        ],
      ),
    );
  }
}

class _FocusAreaChip extends StatelessWidget {
  const _FocusAreaChip({
    required this.area,
    required this.selected,
    required this.onTap,
  });
  final FocusArea area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.arctic;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 108,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 2.4,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: ColorFiltered(
                  colorFilter: selected
                      ? const ColorFilter.mode(
                          Colors.transparent, BlendMode.multiply)
                      : ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.35),
                          BlendMode.darken,
                        ),
                  child: Image.asset(area.asset, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              area.label,
              style: TextStyle(
                color: selected ? palette.chalk : palette.mist,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionChip extends StatelessWidget {
  const _PositionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.arctic;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : palette.hairline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : palette.mist,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.abyss.withValues(alpha: 0),
            palette.abyss,
            palette.abyss,
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Material(
          color: palette.arctic,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(
              child: Text(
                'CONTINUE',
                style: GoogleFonts.plusJakartaSans(
                  color: palette.chalk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on ExerciseDifficulty {
  String get label => switch (this) {
        ExerciseDifficulty.beginner => 'Beginner',
        ExerciseDifficulty.intermediate => 'Intermediate',
        ExerciseDifficulty.advanced => 'Advanced',
      };
}

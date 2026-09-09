import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// One row of the mission timeline. Two states:
///   * "active" — big hero card with placeholder photo, day title, mins/kcal,
///     and a START TRAINING CTA (that's the tap target for the current day).
///   * "queued" — compact row with a small thumb, DAY N, mins/kcal.
///
/// Both states call [onTap] when pressed. Images are placeholder gradients
/// until the real workout thumbnails ship.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.day,
    required this.isActive,
    required this.onTap,
  });

  final PlanDay day;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return isActive ? _ActiveDayCard(day: day, onTap: onTap) : _QueuedDayCard(day: day, onTap: onTap);
  }
}

class _ActiveDayCard extends StatelessWidget {
  const _ActiveDayCard({required this.day, required this.onTap});

  final PlanDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TacticalPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TacticalPalette.arctic.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: TacticalPalette.arctic.withOpacity(0.22),
            blurRadius: 24,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _WorkoutPlaceholder(
            title: day.title,
            minutes: day.estimatedMinutes,
            calories: day.estimatedCalories,
            height: 190,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'DAY ${day.dayIndex}',
                      style: GoogleFonts.bigShouldersDisplay(
                        color: TacticalPalette.chalk,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 1.2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _weekdayLabel(day.dayIndex),
                        style: TextStyle(
                          color: TacticalPalette.mist,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _StartTrainingButton(onTap: onTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedDayCard extends StatelessWidget {
  const _QueuedDayCard({required this.day, required this.onTap});

  final PlanDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TacticalPalette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _WorkoutPlaceholder(
                title: day.title,
                minutes: day.estimatedMinutes,
                calories: day.estimatedCalories,
                compact: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'DAY ${day.dayIndex}',
                      style: GoogleFonts.bigShouldersDisplay(
                        color: TacticalPalette.chalk,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 1.1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${day.estimatedMinutes} Mins  ·  ${day.estimatedCalories} Kcal',
                      style: TextStyle(
                        color: TacticalPalette.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: TacticalPalette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blue-camo gradient tile that stands in for the workout thumbnail until
/// the real photos land. Big variant is used on the active day card, the
/// small `compact` variant is the leading thumb on queued day rows.
class _WorkoutPlaceholder extends StatelessWidget {
  const _WorkoutPlaceholder({
    required this.title,
    required this.minutes,
    required this.calories,
    this.height,
    this.compact = false,
  });

  final String title;
  final int minutes;
  final int calories;
  final double? height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 72,
          height: 72,
          child: _PlaceholderBg(seed: title.hashCode),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PlaceholderBg(seed: title.hashCode),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.bigShouldersDisplay(
                    color: TacticalPalette.chalk,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    letterSpacing: 1.1,
                    height: 1,
                    shadows: [
                      const Shadow(
                        blurRadius: 10,
                        color: Colors.black87,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$minutes Mins  ·  $calories Kcal',
                  style: TextStyle(
                    color: TacticalPalette.chalk.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        blurRadius: 6,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tiny "PLACEHOLDER" ribbon in the top-right so it's clear the
          // photography is coming later — remove once real thumbs ship.
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: TacticalPalette.abyss.withOpacity(0.55),
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: TacticalPalette.arcticSoft.withOpacity(0.6)),
              ),
              child: Text(
                'PLACEHOLDER',
                style: GoogleFonts.jetBrainsMono(
                  color: TacticalPalette.arcticSoft,
                  fontSize: 8,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBg extends StatelessWidget {
  const _PlaceholderBg({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    // Rotate through a small palette of blue-camo gradient variants so
    // adjacent day placeholders don't look identical.
    final variants = <List<Color>>[
      [TacticalPalette.arcticDeep, TacticalPalette.midnight],
      [TacticalPalette.surfaceHigh, TacticalPalette.abyss],
      [TacticalPalette.arctic, TacticalPalette.arcticDeep],
      [TacticalPalette.midnight, TacticalPalette.surface],
    ];
    final colors = variants[seed.abs() % variants.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TacticalPalette.arcticSoft.withOpacity(0.08),
            ),
          ),
        ),
        Center(
          child: Opacity(
            opacity: 0.25,
            child: Icon(
              Icons.fitness_center_rounded,
              color: TacticalPalette.chalk,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }
}

class _StartTrainingButton extends StatelessWidget {
  const _StartTrainingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [
                  TacticalPalette.arcticDeep,
                  TacticalPalette.arctic,
                ],
              ),
              border: Border.all(
                color: TacticalPalette.glacier.withOpacity(0.6),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'START TRAINING',
              style: GoogleFonts.bigShouldersDisplay(
                color: TacticalPalette.chalk,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _weekdayLabel(int day) {
  // Map day-of-mission → weekday abbreviation starting on a Monday.
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${names[(day - 1) % 7]}.$day';
}

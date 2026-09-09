import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

/// Recruit rank / stage / stars strip that sits below the plan title on
/// the home screen. Fully self-contained — the home screen just hands it
/// the current values.
class SquadStatusCard extends StatelessWidget {
  const SquadStatusCard({
    super.key,
    required this.rank,
    required this.stageIndex,
    required this.totalStages,
    required this.starsEarned,
    required this.starsTotal,
  });

  final String rank;
  final int stageIndex;
  final int totalStages;
  final int starsEarned;
  final int starsTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TacticalPalette.arcticDeep.withOpacity(0.35),
            TacticalPalette.surface.withOpacity(0.9),
          ],
        ),
        border: Border.all(
          color: TacticalPalette.arctic.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: TacticalPalette.arctic.withOpacity(0.18),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          const _RankShield(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SQUAD STATUS',
                  style: GoogleFonts.jetBrainsMono(
                    color: TacticalPalette.arcticSoft,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rank,
                  style: GoogleFonts.bigShouldersDisplay(
                    color: TacticalPalette.chalk,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: 1.2,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 46, color: TacticalPalette.hairline),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: TacticalPalette.arctic.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: TacticalPalette.arctic.withOpacity(0.6),
                  ),
                ),
                child: Text(
                  'STAGE $stageIndex / $totalStages',
                  style: GoogleFonts.jetBrainsMono(
                    color: TacticalPalette.glacier,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _StarRow(earned: starsEarned, total: starsTotal),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankShield extends StatelessWidget {
  const _RankShield();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TacticalPalette.arctic, TacticalPalette.arcticDeep],
        ),
        border: Border.all(
          color: TacticalPalette.glacier.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: TacticalPalette.arctic.withOpacity(0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_moon_outlined,
        color: TacticalPalette.chalk,
        size: 26,
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.earned, required this.total});

  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < earned;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14,
            color: filled
                ? TacticalPalette.warning
                : TacticalPalette.muted.withOpacity(0.7),
          ),
        );
      }),
    );
  }
}

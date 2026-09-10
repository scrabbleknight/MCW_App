import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Recruit rank / stage / stars strip that sits below the plan title on
/// the home screen. Renders a "premium loot card" — dark textured ground with
/// a soft blue vignette, embossed shield emblem on the left, big rank text,
/// bordered STAGE pill and gold star row on the right. Adapts palette to
/// both brightnesses so it reads rich in dark mode and crisp in light mode.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ground gradient — a deep near-black wash in dark mode, a soft cool
    // cream in light mode. Both get a subtle blue radial glow behind the
    // shield to lift the emblem off the surface.
    final baseGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E17), Color(0xFF141A26), Color(0xFF0A0E17)],
            stops: [0.0, 0.55, 1.0],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF3FB), Color(0xFFFFFFFF), Color(0xFFEFF3FB)],
            stops: [0.0, 0.55, 1.0],
          );

    final borderColor = isDark
        ? const Color(0xFF3B82F6).withOpacity(0.55)
        : const Color(0xFF2563EB).withOpacity(0.45);
    final rankColor = isDark ? Colors.white : const Color(0xFF0B111C);
    final labelColor = isDark
        ? const Color(0xFF6FA8DC)
        : const Color(0xFF2563EB);
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.10)
        : const Color(0xFF2563EB).withOpacity(0.18);

    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: baseGradient,
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB))
                .withOpacity(isDark ? 0.22 : 0.14),
            blurRadius: 22,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            // Soft blue radial glow behind the shield emblem.
            Positioned(
              left: -80,
              top: -60,
              bottom: -60,
              width: 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      (isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF2563EB))
                          .withOpacity(isDark ? 0.32 : 0.18),
                      (isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF2563EB))
                          .withOpacity(isDark ? 0.10 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _RankShield(isDark: isDark, rank: rank),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'STATUS',
                          style: GoogleFonts.plusJakartaSans(
                            color: labelColor,
                            fontSize: 11,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            rank,
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.plusJakartaSans(
                              color: rankColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              letterSpacing: 1.4,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StagePill(
                        text: 'STAGE $stageIndex / $totalStages',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _StarRow(
                        earned: starsEarned,
                        total: starsTotal,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.55), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: accent,
          fontSize: 11,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RankShield extends StatelessWidget {
  const _RankShield({required this.isDark, required this.rank});

  final bool isDark;
  final String rank;

  static const _badges = <String, String>{
    'RECRUIT': 'assets/branding/recruit_badge.png',
    'PRIVATE': 'assets/branding/private_badge.png',
    'CORPORAL': 'assets/branding/corporal_badge.png',
    'SERGEANT': 'assets/branding/sergeant_badge.png',
    'LIEUTENANT': 'assets/branding/lieutenant_badge.png',
    'CAPTAIN': 'assets/branding/captain_badge.png',
    'GENERAL': 'assets/branding/general_badge.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _badges[rank.toUpperCase()] ?? _badges['RECRUIT']!;
    final glow = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
      width: 64,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(isDark ? 0.45 : 0.28),
              blurRadius: 18,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.shield_moon_outlined,
            color: isDark ? Colors.white : const Color(0xFF0B111C),
            size: 32,
          ),
        ),
      ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.earned,
    required this.total,
    required this.isDark,
  });

  final int earned;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final empty = isDark
        ? Colors.white.withOpacity(0.28)
        : const Color(0xFF2563EB).withOpacity(0.28);
    const gold = Color(0xFFF5B840);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < earned;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 15,
            color: filled ? gold : empty,
          ),
        );
      }),
    );
  }
}

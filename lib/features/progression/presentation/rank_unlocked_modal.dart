import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/features/progression/domain/rank.dart';

/// Full-screen celebration modal fired the first time the user crosses into a
/// new [Rank]. Big shining badge above a dark card with the app's arctic-blue
/// glow, a "You're now a XXX." pill, a wings-and-star divider, an in-character
/// citation, and a "CONTINUE MY MISSION" CTA that pops the dialog. Sibling of
/// [MissionCompleteModal] — same visual DNA, blown up for a bigger event.
class RankUnlockedModal extends StatelessWidget {
  const RankUnlockedModal({
    super.key,
    required this.rank,
    required this.onContinue,
  });

  final Rank rank;
  final VoidCallback onContinue;

  static Future<void> show(BuildContext context, {required Rank rank}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (ctx) => RankUnlockedModal(
        rank: rank,
        onContinue: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          _CardBody(rank: rank, onContinue: onContinue),
          const Positioned(
            top: -110,
            child: SizedBox(
              width: 300,
              height: 280,
              child: IgnorePointer(
                child: CustomPaint(painter: _LightRaysPainter()),
              ),
            ),
          ),
          Positioned(
            top: -70,
            child: _ShiningBadge(assetPath: rank.asset),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CARD BODY
// ---------------------------------------------------------------------------

class _CardBody extends StatelessWidget {
  const _CardBody({required this.rank, required this.onContinue});

  final Rank rank;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 160, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141C2B), Color(0xFF0B111C)],
        ),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.34),
            blurRadius: 32,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rank Unlocked',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          _RankPill(label: rank.label),
          const SizedBox(height: 22),
          const _WingsDivider(),
          const SizedBox(height: 20),
          Text(
            rank.citation,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _ContinueButton(onTap: onContinue),
        ],
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.label});
  final String label;

  static const _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: Text(
        "You're now a ${label.toUpperCase()}.",
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF93C5FD),
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Text(
          'CONTINUE MY MISSION',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHINING BADGE + LIGHT RAYS
// ---------------------------------------------------------------------------

class _ShiningBadge extends StatelessWidget {
  const _ShiningBadge({required this.assetPath});
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft radial glow directly behind the badge.
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF3B82F6).withValues(alpha: 0.55),
                  const Color(0xFF3B82F6).withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Image.asset(
            assetPath,
            width: 130,
            height: 130,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.shield_rounded,
              color: Color(0xFF3B82F6),
              size: 100,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fans light-ray triangles outward from the top-center of the card, behind
/// the badge, echoing the sunburst in the reference mock.
class _LightRaysPainter extends CustomPainter {
  const _LightRaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final rayLength = size.width * 0.75;
    const rayCount = 14;
    // Sweep the rays across the top ~180°, biased to fan out roughly like
    // the mock (dense above the badge, thinning toward the horizon).
    const startAngle = -math.pi;
    const endAngle = 0.0;
    final step = (endAngle - startAngle) / (rayCount - 1);
    final paint = Paint()..blendMode = BlendMode.plus;

    for (var i = 0; i < rayCount; i++) {
      final angle = startAngle + step * i;
      final tip = origin + Offset(math.cos(angle), math.sin(angle)) * rayLength;
      final perp = Offset(-math.sin(angle), math.cos(angle));
      // Every other ray a hair thinner + shorter for a naturalistic burst.
      final wideBase = (i.isEven ? 12.0 : 7.0);
      final trimmedLength = i.isEven ? rayLength : rayLength * 0.72;
      final trimmedTip = origin + (tip - origin) * (trimmedLength / rayLength);
      final p1 = origin + perp * (wideBase / 2);
      final p2 = origin - perp * (wideBase / 2);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(trimmedTip.dx, trimmedTip.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      paint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.42),
          const Color(0xFF3B82F6).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromPoints(origin, trimmedTip),
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightRaysPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// WINGS DIVIDER
// ---------------------------------------------------------------------------

class _WingsDivider extends StatelessWidget {
  const _WingsDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: CustomPaint(
        painter: _WingsPainter(),
        size: const Size(double.infinity, 24),
      ),
    );
  }
}

class _WingsPainter extends CustomPainter {
  static const _gold = Color(0xFFF5D07A);
  static const _goldDeep = Color(0xFFB68A2A);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final midY = size.height / 2;
    final line = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, _goldDeep, _gold, _goldDeep, Colors.transparent],
        stops: const [0, 0.15, 0.5, 0.85, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Horizontal line broken by the center star.
    canvas.drawLine(
      Offset(size.width * 0.06, midY),
      Offset(centerX - 22, midY),
      line,
    );
    canvas.drawLine(
      Offset(centerX + 22, midY),
      Offset(size.width * 0.94, midY),
      line,
    );

    // Wing chevrons — 3 short strokes tapering from the star outward on each
    // side, sloped slightly up to read like a set of wings.
    final wing = Paint()
      ..color = _gold
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final offset = 26.0 + i * 10;
      final tilt = 2.5 + i * 1.5;
      canvas.drawLine(
        Offset(centerX - offset, midY),
        Offset(centerX - offset - 8, midY - tilt),
        wing,
      );
      canvas.drawLine(
        Offset(centerX + offset, midY),
        Offset(centerX + offset + 8, midY - tilt),
        wing,
      );
    }

    // Center 5-point star.
    final starPath = _starPath(Offset(centerX, midY), outer: 9, inner: 4);
    canvas.drawPath(
      starPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gold, _goldDeep],
        ).createShader(Rect.fromCircle(center: Offset(centerX, midY), radius: 10)),
    );
  }

  Path _starPath(Offset center, {required double outer, required double inner}) {
    final path = Path();
    const points = 5;
    const step = math.pi / points;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * step;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _WingsPainter oldDelegate) => false;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

/// Post-paywall "welcome to the squad" reveal — the reward moment that
/// follows the hard paywall. Styled as a tactical enlistment dossier
/// rather than the generic reference (star chip / centred text). The hero
/// photo sits inside a dogeared field-manual frame, an ENLISTED stamp
/// slaps down over it, and three objective cards read like mission
/// pillars from a briefing packet.
class SquadWelcomeStep extends StatefulWidget {
  const SquadWelcomeStep({super.key, required this.onDeploy});

  final VoidCallback onDeploy;

  @override
  State<SquadWelcomeStep> createState() => _SquadWelcomeStepState();
}

class _SquadWelcomeStepState extends State<SquadWelcomeStep>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final String _squadId;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // Randomly generated per session — reinforces the "you've been assigned"
    // narrative without needing any persistent recruit-id backend.
    final rng = math.Random();
    final block = List.generate(3, (_) => rng.nextInt(10)).join();
    _squadId = 'MC-W · 21D · $block-${rng.nextInt(900) + 100}';
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return DecoratedBox(
      decoration: const BoxDecoration(color: TacticalPalette.abyss),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layered backdrop: hand-designed camo, dimmed toward the bottom
          // so the mission cards read against a near-black field.
          Image.asset(
            'assets/branding/camo_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const _CamoScrim(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _SquadTag(id: _squadId),
                  const SizedBox(height: 14),
                  _HeroDossier(
                    intro: _intro,
                    height: math.min(size.height * 0.38, 320),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Title(intro: _intro),
                          const SizedBox(height: 20),
                          _ObjectivesBoard(pulse: _pulse),
                          const SizedBox(height: 16),
                          const _OathLine(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  _DeployButton(onTap: widget.onDeploy, pulse: _pulse),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark radial vignette + light diagonal scanline sheen. Keeps the busy
/// camo readable behind text without flattening the photo above.
class _CamoScrim extends StatelessWidget {
  const _CamoScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.3,
            colors: [
              TacticalPalette.abyss.withOpacity(0.25),
              TacticalPalette.abyss.withOpacity(0.92),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Small dog-tag-style header with a blinking LED and the recruit's
/// generated squad id — grounds the page as a personal enlistment record.
class _SquadTag extends StatelessWidget {
  const _SquadTag({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: TacticalPalette.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TacticalPalette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: TacticalPalette.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: TacticalPalette.success.withOpacity(0.7),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            id,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: TacticalPalette.mist,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Field-manual frame around the hero photo with a rotated ENLISTED stamp
/// that snaps down as the screen enters.
class _HeroDossier extends StatelessWidget {
  const _HeroDossier({required this.intro, required this.height});

  final Animation<double> intro;
  final double height;

  @override
  Widget build(BuildContext context) {
    final stamp = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.55, 1.0, curve: Curves.elasticOut),
    );
    final photo = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: intro,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, (1 - photo.value) * 20),
        child: Opacity(
          opacity: photo.value,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/branding/final_onboarding_page_image.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  // Photo darkening toward the bottom for legibility of the
                  // corner brackets and stamp.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          TacticalPalette.abyss.withOpacity(0.55),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                  const _CornerBrackets(),
                  // "CLASSIFIED" ribbon along the top-left corner.
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TacticalPalette.abyss.withOpacity(0.7),
                        border: Border.all(
                            color: TacticalPalette.arcticSoft
                                .withOpacity(0.9)),
                      ),
                      child: Text(
                        'CLASSIFIED · FILE 021',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: TacticalPalette.arcticSoft,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Enlisted stamp — rotates in with an elastic bounce.
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: Transform.scale(
                      scale: stamp.value.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: -0.18,
                        child: _EnlistedStamp(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Text(
                      'RECRUIT\nCLEARED',
                      style: GoogleFonts.bigShouldersDisplay(
                        color: TacticalPalette.chalk,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                        fontSize: 22,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    const color = TacticalPalette.arcticSoft;
    Widget corner({required Alignment align}) {
      final isTop = align.y < 0;
      final isLeft = align.x < 0;
      return Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _CornerPainter(
                color: color,
                isTop: isTop,
                isLeft: isLeft,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(align: Alignment.topLeft),
        corner(align: Alignment.topRight),
        corner(align: Alignment.bottomLeft),
        corner(align: Alignment.bottomRight),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.color,
    required this.isTop,
    required this.isLeft,
  });

  final Color color;
  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? 1.0 : -1.0;
    final dy = isTop ? 1.0 : -1.0;
    canvas.drawLine(Offset(x, y), Offset(x + dx * size.width, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy * size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

class _EnlistedStamp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: TacticalPalette.arctic, width: 3),
        borderRadius: BorderRadius.circular(4),
        color: TacticalPalette.arctic.withOpacity(0.12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'ENLISTED',
            style: GoogleFonts.bigShouldersDisplay(
              fontWeight: FontWeight.w900,
              color: TacticalPalette.arctic,
              fontSize: 26,
              letterSpacing: 3,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '21-DAY MISSION',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: TacticalPalette.arctic,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.intro});

  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.25, 0.9, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) => Opacity(
        opacity: fade.value,
        child: Transform.translate(
          offset: Offset(0, (1 - fade.value) * 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 2,
                    color: TacticalPalette.arcticSoft,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BRIEFING · 21 DAYS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: TacticalPalette.arcticSoft,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    TacticalPalette.chalk,
                    TacticalPalette.glacier,
                  ],
                ).createShader(bounds),
                child: Text(
                  'WELCOME TO\nTHE SQUAD',
                  style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 44,
                    height: 0.9,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "You're locked in. Boots on. Your 21-day operation "
                'starts on the next screen.',
                style: TextStyle(
                  color: TacticalPalette.mist,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of three tactical objectives — each rendered as a numbered dossier
/// card with a rank badge and a status LED.
class _ObjectivesBoard extends StatelessWidget {
  const _ObjectivesBoard({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _ObjectiveCard(
            index: '01',
            rank: 'PVT',
            title: 'REPORT DAILY',
            body: 'One focused session. Show up, stack the day.',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ObjectiveCard(
            index: '02',
            rank: 'CPL',
            title: 'EARN STRIPES',
            body: 'Every mission logged pushes your rank up.',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ObjectiveCard(
            index: '03',
            rank: 'SGT',
            title: 'HOLD THE LINE',
            body: 'Streaks unlock milestones and new drills.',
          ),
        ),
      ],
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({
    required this.index,
    required this.rank,
    required this.title,
    required this.body,
  });

  final String index;
  final String rank;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: TacticalPalette.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TacticalPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                index,
                style: GoogleFonts.jetBrainsMono(
                  color: TacticalPalette.arcticSoft,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: TacticalPalette.arctic.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: TacticalPalette.arctic.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  rank,
                  style: GoogleFonts.jetBrainsMono(
                    color: TacticalPalette.glacier,
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.bigShouldersDisplay(
              color: TacticalPalette.chalk,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.1,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: TacticalPalette.muted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _OathLine extends StatelessWidget {
  const _OathLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: TacticalPalette.arctic.withOpacity(0.8),
            width: 3,
          ),
        ),
      ),
      child: Text(
        '"Discipline over motivation. Reps over hype." — SQUAD OATH',
        style: TextStyle(
          color: TacticalPalette.mist,
          fontStyle: FontStyle.italic,
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }
}

class _DeployButton extends StatelessWidget {
  const _DeployButton({required this.onTap, required this.pulse});

  final VoidCallback onTap;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = 6 + pulse.value * 14;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 62,
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
                    color: TacticalPalette.arctic.withOpacity(0.55),
                    blurRadius: glow,
                    spreadRadius: 0.5,
                  ),
                ],
                border: Border.all(
                  color: TacticalPalette.glacier.withOpacity(0.6),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chevron_right_rounded,
                      color: TacticalPalette.chalk),
                  const SizedBox(width: 4),
                  Text(
                    'DEPLOY — BEGIN MISSION',
                    style: GoogleFonts.bigShouldersDisplay(
                      color: TacticalPalette.chalk,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: TacticalPalette.chalk),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

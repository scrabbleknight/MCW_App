import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

/// One-shot intro shown on cold app launch: the camo backdrop fades up,
/// tactical corner brackets and a sergeant's insignia draw themselves in,
/// the wordmark tracks into place, then everything pushes forward into the
/// app. Drawn in code (no video), so it's crisp at any size and starts
/// instantly. Tap anywhere to skip.
///
/// Always dark, whatever the app theme: it follows the native splash, which
/// is near-black.
class LaunchAnimationScreen extends StatefulWidget {
  const LaunchAnimationScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<LaunchAnimationScreen> createState() => _LaunchAnimationScreenState();
}

class _LaunchAnimationScreenState extends State<LaunchAnimationScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2600);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _complete();
    });

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progress of [_c] within [begin]–[end] (fractions of the whole run),
  /// eased with [curve].
  double _seg(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    final t = ((_c.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TacticalPalette.abyss,
      body: GestureDetector(
        onTap: _complete,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final exit = _seg(0.86, 1.0, Curves.easeInCubic);
            return Opacity(
              opacity: 1 - exit,
              child: Transform.scale(
                scale: 1 + exit * 0.08,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _backdrop(),
                    CustomPaint(
                      painter: _HudPainter(
                        brackets: _seg(0.04, 0.28),
                        scan: _seg(0.06, 0.5, Curves.easeInOutSine),
                      ),
                    ),
                    _content(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _backdrop() {
    final fade = _seg(0.0, 0.18);
    // Slow push-in across the whole run.
    final zoom = 1.14 - 0.1 * Curves.easeOut.transform(_c.value);
    return Opacity(
      opacity: fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: zoom,
            child: Image.asset(
              'assets/branding/camo_background.webp',
              fit: BoxFit.cover,
            ),
          ),
          // Darken towards the edges so the insignia and title glow.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.12),
                radius: 1.05,
                colors: [Color(0x66061226), Color(0xF205070C)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final insignia = _seg(0.12, 0.46);
    final star = _seg(0.34, 0.52, Curves.elasticOut);
    final glow = _seg(0.4, 0.6) * (1 - _seg(0.7, 0.86));
    final line = _seg(0.56, 0.7);
    final tag = _seg(0.62, 0.76);
    final shine = _seg(0.66, 0.84, Curves.easeInOut);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final width = math.min(box.maxWidth, 440.0);
          final badge = width * 0.42;
          return Column(
            children: [
              const Spacer(flex: 5),
              SizedBox(
                width: badge,
                height: badge * 1.12,
                child: CustomPaint(
                  painter: _InsigniaPainter(
                    frame: _seg(0.06, 0.36, Curves.easeInOutCubic),
                    chevrons: insignia,
                    star: star,
                    glow: glow,
                  ),
                ),
              ),
              SizedBox(height: width * 0.13),
              _TrackedWord(
                text: 'MILITARY',
                progress: _seg(0.38, 0.66),
                fontSize: width * 0.115,
                weight: FontWeight.w900,
                shine: shine,
              ),
              SizedBox(height: width * 0.01),
              _TrackedWord(
                text: 'CALISTHENICS',
                progress: _seg(0.46, 0.74),
                fontSize: width * 0.082,
                weight: FontWeight.w800,
                shine: shine,
              ),
              SizedBox(height: width * 0.05),
              // Divider opening out from the centre.
              Container(
                width: width * 0.5 * line,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TacticalPalette.arctic.withValues(alpha: 0),
                      TacticalPalette.glacier,
                      TacticalPalette.arctic.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              SizedBox(height: width * 0.04),
              Opacity(
                opacity: tag,
                child: Text(
                  'FOR WOMEN',
                  style: GoogleFonts.plusJakartaSans(
                    color: TacticalPalette.glacier,
                    fontWeight: FontWeight.w700,
                    fontSize: width * 0.036,
                    letterSpacing: width * 0.036 * (0.9 - 0.3 * tag),
                  ),
                ),
              ),
              const Spacer(flex: 6),
              Opacity(
                opacity: _seg(0.5, 0.7) * 0.7,
                child: Text(
                  'DEEP BLUE',
                  style: GoogleFonts.plusJakartaSans(
                    color: TacticalPalette.mist,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// A word whose letters slide up and fade in one after another while the
/// tracking tightens, with an optional light sweep across it.
class _TrackedWord extends StatelessWidget {
  const _TrackedWord({
    required this.text,
    required this.progress,
    required this.fontSize,
    required this.weight,
    required this.shine,
  });

  final String text;
  final double progress;
  final double fontSize;
  final FontWeight weight;
  final double shine;

  @override
  Widget build(BuildContext context) {
    final letters = text.split('');
    // Starts slightly wide and settles; kept modest so the longest word
    // still fits the screen at its widest.
    final spacing = fontSize * (0.1 + 0.12 * (1 - progress));
    final style = GoogleFonts.plusJakartaSans(
      color: Colors.white,
      fontWeight: weight,
      fontSize: fontSize,
      height: 1,
      letterSpacing: spacing,
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          Builder(builder: (context) {
            // Each letter gets its own window inside the word's progress.
            final start = i / (letters.length + 4);
            final t = ((progress - start) / 0.35).clamp(0.0, 1.0);
            final eased = Curves.easeOutCubic.transform(t);
            return Opacity(
              opacity: eased,
              child: Transform.translate(
                offset: Offset(0, fontSize * 0.4 * (1 - eased)),
                child: Text(letters[i], style: style),
              ),
            );
          }),
      ],
    );
    if (shine <= 0 || shine >= 1) return FittedBox(fit: BoxFit.scaleDown, child: row);
    // A soft band of light crossing left to right.
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final x = -0.4 + 1.8 * shine;
        return LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            TacticalPalette.glacier,
            Colors.white.withValues(alpha: 0),
          ],
          stops: [
            (x - 0.18).clamp(0.0, 1.0),
            x.clamp(0.0, 1.0),
            (x + 0.18).clamp(0.0, 1.0),
          ],
        ).createShader(rect);
      },
      child: FittedBox(fit: BoxFit.scaleDown, child: row),
    );
  }
}

/// Corner brackets that draw in from each corner, plus one scan line that
/// sweeps down the screen.
class _HudPainter extends CustomPainter {
  _HudPainter({required this.brackets, required this.scan});

  final double brackets;
  final double scan;

  @override
  void paint(Canvas canvas, Size size) {
    if (brackets > 0) {
      final paint = Paint()
        ..color = TacticalPalette.glacier.withValues(alpha: 0.55 * brackets)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;
      const inset = 28.0;
      final arm = 34.0 * brackets;
      final corners = [
        (Offset(inset, inset + 40), 1.0, 1.0),
        (Offset(size.width - inset, inset + 40), -1.0, 1.0),
        (Offset(inset, size.height - inset - 30), 1.0, -1.0),
        (Offset(size.width - inset, size.height - inset - 30), -1.0, -1.0),
      ];
      for (final (o, dx, dy) in corners) {
        canvas.drawLine(o, o + Offset(arm * dx, 0), paint);
        canvas.drawLine(o, o + Offset(0, arm * dy), paint);
      }
    }
    if (scan > 0 && scan < 1) {
      final y = size.height * scan;
      final band = Rect.fromLTWH(0, y - 60, size.width, 60);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TacticalPalette.arctic.withValues(alpha: 0),
              TacticalPalette.arctic.withValues(alpha: 0.16),
            ],
          ).createShader(band),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = TacticalPalette.glacier.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_HudPainter old) =>
      old.brackets != brackets || old.scan != scan;
}

/// Three chevrons that draw themselves from the bottom up, filling as they
/// finish, topped by a star that pops in with a glow.
class _InsigniaPainter extends CustomPainter {
  _InsigniaPainter({
    required this.frame,
    required this.chevrons,
    required this.star,
    required this.glow,
  });

  final double frame;
  final double chevrons;
  final double star;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.085;

    // Hexagon badge outline tracing itself round from the top.
    if (frame > 0) {
      final c = Offset(w * 0.5, h * 0.5);
      final r = h * 0.62;
      final hex = Path();
      for (var i = 0; i <= 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
      }
      final metric = hex.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * frame),
        Paint()
          ..color = TacticalPalette.glacier.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.018
          ..strokeJoin = StrokeJoin.miter,
      );
      // Faint fill once the outline closes.
      if (frame >= 1) {
        canvas.drawPath(
          hex,
          Paint()..color = TacticalPalette.arcticDeep.withValues(alpha: 0.14),
        );
      }
    }

    // Chevrons: bottom first, each starting a little after the last.
    for (var i = 0; i < 3; i++) {
      final t = ((chevrons - i * 0.18) / 0.64).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final top = h * (0.78 - i * 0.17);
      final path = Path()
        ..moveTo(w * 0.08, top + h * 0.17)
        ..lineTo(w * 0.5, top)
        ..lineTo(w * 0.92, top + h * 0.17);
      final metric = path.computeMetrics().first;
      // Draw outward from the peak so both arms grow together.
      final half = metric.length / 2;
      final partial = Path()
        ..addPath(
          metric.extractPath(half - half * t, half + half * t),
          Offset.zero,
        );
      canvas.drawPath(
        partial,
        Paint()
          ..color = Color.lerp(
            TacticalPalette.arcticDeep,
            TacticalPalette.glacier,
            t,
          )!
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.miter
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Star above the chevrons.
    if (star > 0) {
      final center = Offset(w * 0.5, h * 0.2);
      final r = w * 0.16 * star;
      if (glow > 0) {
        canvas.drawCircle(
          center,
          r * 2.4,
          Paint()
            ..color = TacticalPalette.arctic.withValues(alpha: 0.5 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.2),
        );
      }
      canvas.drawPath(
        _starPath(center, r, r * 0.42),
        Paint()..color = Colors.white,
      );
    }
  }

  Path _starPath(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_InsigniaPainter old) =>
      old.frame != frame ||
      old.chevrons != chevrons ||
      old.star != star ||
      old.glow != glow;
}

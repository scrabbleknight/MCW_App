import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/current_weight_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/goal_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_duration_step.dart';

/// Post-calibration plan preview. Header projection chart → trainer card →
/// calendar → (later: muscle map & week-by-week exercises) → sticky CTA.
///
/// This file only draws the top three sections. The remaining sections go
/// below the calendar; the sticky bottom CTA and the scroll body are already
/// wired so slotting more content in later is a one-liner.
class PlanPreviewStep extends StatelessWidget {
  const PlanPreviewStep({
    super.key,
    required this.currentWeight,
    required this.goalWeight,
    required this.trainer,
    required this.goal,
    required this.workoutDuration,
    required this.dailyCalorieTarget,
    required this.onConfirm,
    this.onFeelingChanged,
  });

  final WeightAnswer currentWeight;
  final WeightAnswer goalWeight;
  final Trainer trainer;
  final FitnessGoal? goal;
  final WorkoutDuration? workoutDuration;
  final int dailyCalorieTarget;
  final VoidCallback onConfirm;

  /// Fires when the user picks a pre-start feeling. Optional — the flow
  /// still advances even if the user leaves it blank.
  final ValueChanged<PreStartFeeling>? onFeelingChanged;

  @override
  Widget build(BuildContext context) {
    final projection = _projectWeightLoss(
      currentKg: currentWeight.kg,
      goalKg: goalWeight.kg,
      now: DateTime.now(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeightForecastSection(
                  projection: projection,
                  unit: currentWeight.unit,
                ),
                const SizedBox(height: 20),
                _TrainerPlanCard(trainer: trainer),
                const SizedBox(height: 24),
                const _CalendarSection(),
                const SizedBox(height: 24),
                _PlanContentSection(
                  goal: goal,
                  workoutDuration: workoutDuration,
                  dailyCalorieTarget: dailyCalorieTarget,
                ),
                const SizedBox(height: 28),
                const _PlanPreviewSection(),
                const SizedBox(height: 28),
                _PreStartCheckInSection(onChanged: onFeelingChanged),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryCta(
                label: 'Get My Plan Now!',
                trailingIcon: null,
                onPressed: onConfirm,
              ),
              const SizedBox(height: 10),
              const _TermsLine(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsLine extends StatelessWidget {
  const _TermsLine();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final baseStyle = text.bodySmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.65),
    );
    final linkStyle = baseStyle?.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(text: 'Privacy Policy', style: linkStyle),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Terms of Use', style: linkStyle),
        ],
      ),
    );
  }
}

// ============================================================================
// Section 1 — Weight forecast
// ============================================================================

class _WeightProjection {
  const _WeightProjection({
    required this.startKg,
    required this.midKg,
    required this.endKg,
    required this.startDate,
    required this.midDate,
    required this.endDate,
    required this.isLoss,
  });

  final double startKg;
  final double midKg;
  final double endKg;
  final DateTime startDate;
  final DateTime midDate;
  final DateTime endDate;

  /// true → weight-loss trajectory, false → gain trajectory. Drives the
  /// direction of the curve and the label copy.
  final bool isLoss;

  double get absDelta => (startKg - endKg).abs();
}

/// Weight-loss projection used by the forecast chart. A safe / sustainable
/// deficit of ~0.7 kg per week anchors the timeline; the midpoint uses a
/// concave-down curve (early progress is faster) so the visual matches how
/// real fat-loss actually feels.
_WeightProjection _projectWeightLoss({
  required double currentKg,
  required double goalKg,
  required DateTime now,
}) {
  final delta = currentKg - goalKg;
  final isLoss = delta >= 0;
  final abs = delta.abs();
  final rateKgPerWeek = 0.7;
  final totalDays = (abs / rateKgPerWeek * 7).clamp(21, 168).toInt();
  final endDate = now.add(Duration(days: totalDays));
  final midDate = now.add(Duration(days: (totalDays * 0.62).round()));
  // 62% of the way through the timeline the user is ~78% of the way toward
  // their goal — that's the concave-down curve applied to the midpoint.
  final midKg = isLoss ? currentKg - abs * 0.78 : currentKg + abs * 0.78;
  return _WeightProjection(
    startKg: currentKg,
    midKg: midKg,
    endKg: goalKg,
    startDate: now,
    midDate: midDate,
    endDate: endDate,
    isLoss: isLoss,
  );
}

class _WeightForecastSection extends StatelessWidget {
  const _WeightForecastSection({required this.projection, required this.unit});

  final _WeightProjection projection;
  final WeightUnit unit;

  static const _kgPerLb = 0.45359237;

  String _fmt(double kg, {int decimals = 1}) {
    final v = unit == WeightUnit.kg ? kg : kg / _kgPerLb;
    return v.toStringAsFixed(decimals);
  }

  String get _unitLabel => unit == WeightUnit.kg ? 'kg' : 'lbs';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final endDateLabel = _formatLongDate(projection.endDate);
    final endShortLabel = _formatShortDate(projection.endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Based on your answers',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "You'll be ${_fmt(projection.endKg)}$_unitLabel by",
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          endDateLabel,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: _WeightCurveChart(
            projection: projection,
            unit: unit,
            endShortLabel: endShortLabel,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: RichText(
            text: TextSpan(
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.35,
              ),
              children: [
                const TextSpan(
                  text: '85% ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                    text: 'of people in a similar situation to you have lost '),
                TextSpan(
                  text:
                      '${_fmt(projection.absDelta)}$_unitLabel ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                    text: 'after using Military Calisthenics Women.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeightCurveChart extends StatelessWidget {
  const _WeightCurveChart({
    required this.projection,
    required this.unit,
    required this.endShortLabel,
  });

  final _WeightProjection projection;
  final WeightUnit unit;
  final String endShortLabel;

  static const _startColor = Color(0xFFE7594A);
  static const _midColor = Color(0xFFE7C24A);
  static const _endColor = Color(0xFF8FCF52);
  static const _kgPerLb = 0.45359237;

  String _fmtWeight(double kg, {int decimals = 0}) {
    final v = unit == WeightUnit.kg ? kg : kg / _kgPerLb;
    return decimals == 0
        ? v.round().toString()
        : v.toStringAsFixed(decimals);
  }

  String get _unitLabel => unit == WeightUnit.kg ? 'kg' : 'lbs';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Curve occupies vertical band [0.30, 0.75] of the frame. The top
        // 30% is reserved as headroom for the weight tooltips (so they
        // never clip against the chart's top edge on small phones); the
        // bottom 25% holds the x-axis labels.
        const topPad = 0.30;
        const bottomPad = 0.75;
        final positions = _pointPositions(size, topPad, bottomPad);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CurvePainter(positions: positions),
              ),
            ),
            _PointOverlay(
              point: positions[0],
              color: _startColor,
              label: '${_fmtWeight(projection.startKg)}$_unitLabel',
              variant: _LabelVariant.plain,
            ),
            _PointOverlay(
              point: positions[1],
              color: _midColor,
              label: '${_fmtWeight(projection.midKg, decimals: 1)}$_unitLabel',
              variant: _LabelVariant.whiteBubble,
            ),
            _PointOverlay(
              point: positions[2],
              color: _endColor,
              label: '${_fmtWeight(projection.endKg)}$_unitLabel',
              variant: _LabelVariant.filledBubble,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Today',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'After 28 Days',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        endShortLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: _endColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Offset> _pointPositions(Size size, double topPad, double bottomPad) {
    final startX = size.width * 0.12;
    final midX = size.width * 0.42;
    final endX = size.width * 0.86;
    // Height is a function of weight relative to the min/max — the highest
    // weight sits at the top of the curve band, the lowest at the bottom.
    final weights = [
      projection.startKg,
      projection.midKg,
      projection.endKg,
    ];
    final minW = weights.reduce(math.min);
    final maxW = weights.reduce(math.max);
    final range = math.max(0.1, maxW - minW);
    double yFor(double w) {
      final t = (maxW - w) / range; // 0 at max weight, 1 at min weight
      final invT = projection.isLoss ? 1 - t : t;
      return size.height * (topPad + (bottomPad - topPad) * invT);
    }

    return [
      Offset(startX, yFor(projection.startKg)),
      Offset(midX, yFor(projection.midKg)),
      Offset(endX, yFor(projection.endKg)),
    ];
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

/// How the weight number above the dot is drawn.
enum _LabelVariant {
  /// Plain text with no background — used at the first (Today) dot.
  plain,

  /// White pill with black text + a white downward tail. Used at midpoint.
  whiteBubble,

  /// Coloured pill (matches the dot) with white text + coloured tail.
  /// Used at the end / goal dot.
  filledBubble,
}

/// Renders one point of the chart: a coloured dot centred on [point] and a
/// naturally-sized weight label horizontally centred above the dot. Never
/// clips: it sits inside a `Stack(clipBehavior: Clip.none)` and shifts
/// itself with [FractionalTranslation], so it works at any phone width and
/// any label length.
class _PointOverlay extends StatelessWidget {
  const _PointOverlay({
    required this.point,
    required this.color,
    required this.label,
    required this.variant,
  });

  final Offset point;
  final Color color;
  final String label;
  final _LabelVariant variant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: point.dx - 7,
          top: point.dy - 7,
          child: _Dot(color: color),
        ),
        // The label anchors so its bottom-centre sits 10px above the dot.
        // FractionalTranslation lets the widget take its own intrinsic
        // width — no fixed box that could clip the text.
        Positioned(
          left: point.dx,
          top: point.dy - 10,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -1.0),
            child: _buildLabel(),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel() {
    if (variant == _LabelVariant.plain) {
      return Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      );
    }
    final isFilled = variant == _LabelVariant.filledBubble;
    final bubbleColor = isFilled ? color : Colors.white;
    final textColor = isFilled ? Colors.white : Colors.black;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _TooltipTailPainter(color: bubbleColor),
        ),
      ],
    );
  }
}

class _TooltipTailPainter extends CustomPainter {
  const _TooltipTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TooltipTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.positions});

  final List<Offset> positions;

  static const _startColor = Color(0xFFE7594A);
  static const _midColor = Color(0xFFE7C24A);
  static const _endColor = Color(0xFF8FCF52);

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 3) return;
    final p0 = positions[0];
    final p1 = positions[1];
    final p2 = positions[2];

    // Smooth curve through the three points using quadratic segments.
    final path = Path()..moveTo(p0.dx, p0.dy);
    final c1 = Offset(
      (p0.dx + p1.dx) / 2,
      p0.dy + (p1.dy - p0.dy) * 0.9,
    );
    path.quadraticBezierTo(c1.dx, c1.dy, p1.dx, p1.dy);
    final c2 = Offset(
      (p1.dx + p2.dx) / 2,
      p1.dy + (p2.dy - p1.dy) * 0.9,
    );
    path.quadraticBezierTo(c2.dx, c2.dy, p2.dx, p2.dy);

    // Dashed vertical guides at each dot.
    final guidePaint = Paint()
      ..strokeWidth = 1.2
      ..color = const Color(0xFF9AA0A6).withValues(alpha: 0.55);
    for (final p in positions) {
      _drawDashedLine(
        canvas,
        Offset(p.dx, p.dy),
        Offset(p.dx, size.height * 0.75),
        guidePaint,
        dash: 4,
        gap: 4,
      );
    }

    // Fill under the curve — a translucent version of the gradient.
    final fillPath = Path.from(path)
      ..lineTo(p2.dx, size.height * 0.75)
      ..lineTo(p0.dx, size.height * 0.75)
      ..close();
    final fillGradient = LinearGradient(
      colors: [
        _startColor.withValues(alpha: 0.28),
        _midColor.withValues(alpha: 0.22),
        _endColor.withValues(alpha: 0.28),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, Paint()..shader = fillGradient);

    // Curve line with a horizontal red→yellow→green gradient stroke.
    final strokeGradient = LinearGradient(
      colors: [_startColor, _midColor, _endColor],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final strokePaint = Paint()
      ..shader = strokeGradient
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;
    canvas.drawPath(path, strokePaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    double dash = 4,
    double gap = 4,
  }) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final start = from + dir * travelled;
      final segmentLength = math.min(dash, total - travelled);
      final end = from + dir * (travelled + segmentLength);
      canvas.drawLine(start, end, paint);
      travelled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter oldDelegate) =>
      oldDelegate.positions != positions;
}

// ============================================================================
// Section 2 — Trainer plan card
// ============================================================================

class _TrainerPlanCard extends StatelessWidget {
  const _TrainerPlanCard({required this.trainer});
  final Trainer trainer;

  static const _goldTop = Color(0xFFF6E7A9);
  static const _goldBottom = Color(0xFFB68A2A);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final copy = _copyFor(trainer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Plan By ${trainer.displayName}',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_goldTop, _goldBottom, _goldTop],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: const Color(0xFF15181B),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    Positioned(
                      left: -20,
                      bottom: 0,
                      top: 0,
                      width: 200,
                      child: Image.asset(
                        trainer.avatarAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final chip in copy.chips) ...[
                            _TraitChip(label: chip),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _QuoteBubble(
                        heading: copy.quoteHeading,
                        body: copy.quoteBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainerCopy {
  const _TrainerCopy({
    required this.chips,
    required this.quoteHeading,
    required this.quoteBody,
  });

  final List<String> chips;
  final String quoteHeading;
  final String quoteBody;
}

_TrainerCopy _copyFor(Trainer trainer) {
  return switch (trainer) {
    Trainer.hailey => const _TrainerCopy(
        chips: ['FOCUSED', 'UPLIFTING', 'DISCIPLINED'],
        quoteHeading: 'REAL PROGRESS',
        quoteBody:
            "Small daily wins compound.\n— Let's make the tough sessions "
            'feel routine.',
      ),
    Trainer.gemma => const _TrainerCopy(
        chips: ['STEADY', 'HEARTFELT', 'DETERMINED'],
        quoteHeading: 'PURPOSE DRIVEN',
        quoteBody:
            "Show up on the days you don't want to.\n— That's where the "
            'change lives.',
      ),
    Trainer.amy => const _TrainerCopy(
        chips: ['STEADY', 'STRONG', 'SUPPORTIVE'],
        quoteHeading: 'STEADY WINS',
        quoteBody:
            'Consistency beats intensity every time.\n— We build strength '
            'that lasts.',
      ),
  };
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      constraints: const BoxConstraints(minWidth: 130),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _QuoteBubble extends StatelessWidget {
  const _QuoteBubble({required this.heading, required this.body});
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  heading,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 20,
                  ),
                ),
              ),
              const Text(
                '”',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 40,
                  height: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Section 3 — Calendar (image asset — dates are baked in for the preview)
// ============================================================================

class _CalendarSection extends StatelessWidget {
  const _CalendarSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Workout Routine',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Image.asset(
          'assets/branding/calendar.png',
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

// ============================================================================
// Date helpers
// ============================================================================

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatShortDate(DateTime d) {
  return '${_monthsShort[d.month - 1]} ${d.day}';
}

String _formatLongDate(DateTime d) {
  return '${d.day} ${_monthsLong[d.month - 1]}';
}

// ============================================================================
// Section 4 — Plan content card (icons + skeleton muscle diagram)
// ============================================================================

class _PlanContentSection extends StatelessWidget {
  const _PlanContentSection({
    required this.goal,
    required this.workoutDuration,
    required this.dailyCalorieTarget,
  });

  final FitnessGoal? goal;
  final WorkoutDuration? workoutDuration;
  final int dailyCalorieTarget;

  static const _bodyAsset = 'assets/branding/body_image.png';
  static const _stopwatchAsset = 'assets/branding/stopwatch.png';
  static const _caloriesAsset = 'assets/branding/calories_image.png';
  static const _skeletonAsset = 'assets/branding/skeleton.png';

  String get _workoutArea => switch (goal) {
        FitnessGoal.buildStrength => 'Upper body + core',
        FitnessGoal.loseWeight => 'Full body',
        FitnessGoal.recomp => 'Full body',
        FitnessGoal.maintainAndFit => 'Full body',
        null => 'Full body',
      };

  String get _durationLabel => switch (workoutDuration) {
        WorkoutDuration.under10 => 'Under 10 mins',
        WorkoutDuration.tenToFifteen => '10-15 mins',
        WorkoutDuration.fifteenToTwenty => '15-20 mins',
        WorkoutDuration.twentyToThirty => '20-30 mins',
        null => '15-20 mins',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Plan content',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      iconAsset: _bodyAsset,
                      label: 'Workout Area',
                      value: _workoutArea,
                    ),
                    const SizedBox(height: 18),
                    _StatRow(
                      iconAsset: _stopwatchAsset,
                      label: 'Durations',
                      value: _durationLabel,
                    ),
                    const SizedBox(height: 18),
                    _StatRow(
                      iconAsset: _caloriesAsset,
                      label: 'Calories',
                      value: '$dailyCalorieTarget kcal/day',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                height: 240,
                child: Image.asset(_skeletonAsset, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(iconAsset, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Section 5 — Plan preview (per-week exercise thumbnails)
// ============================================================================

/// One thumbnail slot in a week row. Amount labels are baked into the source
/// PNGs so we only surface the image + week grouping here.
class _WeekTile {
  const _WeekTile({required this.asset});
  final String asset;
}

class _WeekPreview {
  const _WeekPreview({
    required this.index,
    required this.title,
    required this.tiles,
  });
  final int index;
  final String title;
  final List<_WeekTile> tiles;
}

// Rep/second labels are baked into the images, so the tiles just render
// the asset. Titles here match the plan-generator's default theme titles.
const _week1 = _WeekPreview(
  index: 1,
  title: 'Body Awakening',
  tiles: [
    _WeekTile(asset: 'assets/branding/week1_x20_1.png'),
    _WeekTile(asset: 'assets/branding/week1_x5_1.png'),
    _WeekTile(asset: 'assets/branding/week1_x5_2.png'),
    _WeekTile(asset: 'assets/branding/week1_x20_2.png'),
  ],
);

const _week2 = _WeekPreview(
  index: 2,
  title: 'Fat Burn Blast',
  tiles: [
    _WeekTile(asset: 'assets/branding/week2_x10_1.png'),
    _WeekTile(asset: 'assets/branding/week2_x10_2.png'),
    _WeekTile(asset: 'assets/branding/week2_x15_1.png'),
    _WeekTile(asset: 'assets/branding/week2_x20_1.png'),
  ],
);

const _week3 = _WeekPreview(
  index: 3,
  title: 'Muscle Strengthening',
  tiles: [
    _WeekTile(asset: 'assets/branding/week3_x15_1.jpg'),
    _WeekTile(asset: 'assets/branding/week3_x15_2.png'),
    _WeekTile(asset: 'assets/branding/week3_x30_1.png'),
    _WeekTile(asset: 'assets/branding/week3_x5_1.png'),
  ],
);

const _week4 = _WeekPreview(
  index: 4,
  title: 'Body Sculpt',
  tiles: [
    _WeekTile(asset: 'assets/branding/week4_x30_1.jpg'),
    _WeekTile(asset: 'assets/branding/week4_x30_2.jpg'),
    _WeekTile(asset: 'assets/branding/week4_x10_1.jpg'),
    _WeekTile(asset: 'assets/branding/week4_x20_1.jpg'),
  ],
);

class _PlanPreviewSection extends StatelessWidget {
  const _PlanPreviewSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Plan Preview',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _WeekRow(week: _week1),
        const SizedBox(height: 20),
        _WeekRow(week: _week2),
        const SizedBox(height: 20),
        _WeekRow(week: _week3),
        const SizedBox(height: 20),
        _WeekRow(week: _week4),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week});
  final _WeekPreview week;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Week ${week.index}',
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          week.title,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < week.tiles.length; i++) ...[
              Expanded(child: _ExerciseTile(tile: week.tiles[i])),
              if (i != week.tiles.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.tile});
  final _WeekTile tile;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.85,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(tile.asset, fit: BoxFit.cover),
      ),
    );
  }
}

// ============================================================================
// Section 6 — Pre-start check-in
// ============================================================================

/// User's sentiment before starting — not required, but useful for opening
/// coach copy in the first session. Stored on the onboarding controller by
/// the parent when [PlanPreviewStep.onFeelingChanged] is passed.
enum PreStartFeeling { excited, willTry, notSure }

class _PreStartCheckInSection extends StatefulWidget {
  const _PreStartCheckInSection({this.onChanged});

  final ValueChanged<PreStartFeeling>? onChanged;

  @override
  State<_PreStartCheckInSection> createState() =>
      _PreStartCheckInSectionState();
}

class _PreStartCheckInSectionState extends State<_PreStartCheckInSection> {
  PreStartFeeling? _selected;

  void _pick(PreStartFeeling value) {
    setState(() => _selected = value);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckInBadge(color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          'How do you feel about starting this plan?',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 18),
        _FeelingTile(
          icon: Icons.check_rounded,
          label: "I'm excited to start",
          selected: _selected == PreStartFeeling.excited,
          onTap: () => _pick(PreStartFeeling.excited),
        ),
        const SizedBox(height: 12),
        _FeelingTile(
          icon: Icons.keyboard_double_arrow_right_rounded,
          label: "Looks good, I'll give it a try",
          selected: _selected == PreStartFeeling.willTry,
          onTap: () => _pick(PreStartFeeling.willTry),
        ),
        const SizedBox(height: 12),
        _FeelingTile(
          icon: Icons.help_outline_rounded,
          label: 'Not sure yet',
          selected: _selected == PreStartFeeling.notSure,
          onTap: () => _pick(PreStartFeeling.notSure),
        ),
      ],
    );
  }
}

/// "PRE-START CHECK IN" pill + three angled bars, mirroring the mockup.
class _CheckInBadge extends StatelessWidget {
  const _CheckInBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'PRE-START CHECK IN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i < 3; i++) ...[
          Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 4,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 + i * 0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeelingTile extends StatelessWidget {
  const _FeelingTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final borderColor =
        selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.35);
    return Material(
      color: selected
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.10),
              scheme.surfaceContainerHighest,
            )
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.hexagon_outlined,
                      size: 42,
                      color: borderColor,
                    ),
                    Icon(
                      icon,
                      size: 20,
                      color: scheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: text.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

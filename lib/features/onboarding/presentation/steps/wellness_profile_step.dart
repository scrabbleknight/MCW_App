import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/features/onboarding/application/plan_recommendation.dart';

/// End-of-onboarding readout: BMI on a coloured scale, plus the plan
/// suggestion (workout area, duration, calories) alongside the hero image.
class WellnessProfileStep extends StatelessWidget {
  const WellnessProfileStep({
    super.key,
    required this.recommendation,
    required this.onContinue,
  });

  final PlanRecommendation recommendation;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Here's your wellness profile",
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BmiCard(recommendation: recommendation),
                const SizedBox(height: 14),
                _PlanCard(recommendation: recommendation),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'BMI metrics/formula from CDC',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryCta(label: 'CONTINUE', onPressed: onContinue),
      ],
    );
  }
}

class _BmiCard extends StatelessWidget {
  const _BmiCard({required this.recommendation});
  final PlanRecommendation recommendation;

  Color _categoryColor(BmiCategory c) => switch (c) {
        BmiCategory.underweight => const Color(0xFF4F9CE0),
        BmiCategory.normal => const Color(0xFF56C271),
        BmiCategory.overweight => const Color(0xFFE7A83A),
        BmiCategory.obese => const Color(0xFFDE5A4A),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final categoryColor = _categoryColor(recommendation.category);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR BMI',
                      style: text.labelLarge?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recommendation.bmi.toStringAsFixed(1),
                      style: text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: categoryColor,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  recommendation.category.label,
                  style: text.titleMedium?.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BmiBar(position: recommendation.barPosition),
          const SizedBox(height: 12),
          Text(
            recommendation.description,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiBar extends StatelessWidget {
  const _BmiBar({required this.position});
  final double position;

  static const _zones = <_ZoneLabel>[
    _ZoneLabel(label: 'Underweight', color: Color(0xFF4F9CE0)),
    _ZoneLabel(label: 'Normal', color: Color(0xFF56C271)),
    _ZoneLabel(label: 'Overweight', color: Color(0xFFE7A83A)),
    _ZoneLabel(label: 'Obese', color: Color(0xFFDE5A4A)),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const indicatorSize = 12.0;
            final left =
                (position * width - indicatorSize / 2).clamp(0.0, width - indicatorSize);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: indicatorSize,
                  child: Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: 0,
                        child: CustomPaint(
                          size: const Size(indicatorSize, indicatorSize),
                          painter: _DownTrianglePainter(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: _zones.map((z) => z.color).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final z in _zones)
              Expanded(
                child: Center(
                  child: Text(
                    z.label,
                    style: text.bodySmall?.copyWith(
                      color: z.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ZoneLabel {
  const _ZoneLabel({required this.label, required this.color});
  final String label;
  final Color color;
}

class _DownTrianglePainter extends CustomPainter {
  const _DownTrianglePainter({required this.color});
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
  bool shouldRepaint(covariant _DownTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.recommendation});
  final PlanRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
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
                _PlanRow(
                  label: 'Workout Area',
                  value: recommendation.workoutArea,
                ),
                const SizedBox(height: 18),
                _PlanRow(
                  label: 'Durations',
                  value: recommendation.durationLabel,
                ),
                const SizedBox(height: 18),
                _PlanRow(
                  label: 'Calories',
                  value: '${recommendation.caloriesPerDay} kcal/day',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            height: 220,
            child: Image.asset(
              'assets/branding/onboarding_hero_16 Background Removed.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label :',
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

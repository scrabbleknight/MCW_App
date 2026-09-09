import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

enum FitnessLevel { newbie, beginner, intermediate, advanced }

const _levels = <_LevelSpec>[
  _LevelSpec(
    label: 'Newbie',
    body: 'Never trained before. We\'ll start you from the ground up.',
  ),
  _LevelSpec(
    label: 'Beginner',
    body: 'Simple movements, low intensity — built for gradual adaptation.',
  ),
  _LevelSpec(
    label: 'Intermediate',
    body: 'Challenging movements and intensity, good for strength building.',
  ),
  _LevelSpec(
    label: 'Advanced',
    body: 'Peak reps, long holds, tough progressions. Bring the pain.',
  ),
];

/// Thirteenth onboarding step — fitness self-assessment on a 4-rank slider.
///
/// Custom visual: stacked chevron insignia (like military rank stripes) that
/// fill in as the slider moves. Fits the tactical brief without borrowing
/// the gauge-ring metaphor of the generic reference.
class FitnessLevelStep extends StatefulWidget {
  const FitnessLevelStep({
    super.key,
    required this.initial,
    required this.onCompleted,
  });

  final FitnessLevel? initial;
  final ValueChanged<FitnessLevel> onCompleted;

  @override
  State<FitnessLevelStep> createState() => _FitnessLevelStepState();
}

class _FitnessLevelStepState extends State<FitnessLevelStep> {
  late int _index = widget.initial?.index ?? 1;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final spec = _levels[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "What's your fitness level?",
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        Center(
          child: SizedBox(
            width: 220,
            height: 200,
            child: _ChevronRank(activeCount: _index + 1),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          spec.label,
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: TacticalPalette.chalk,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            spec.body,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: TacticalPalette.mist,
              height: 1.4,
            ),
          ),
        ),
        const Spacer(),
        _RankSlider(
          index: _index,
          count: _levels.length,
          onChanged: (i) => setState(() => _index = i),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Newbie',
                style: text.labelLarge?.copyWith(
                  color: TacticalPalette.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'Advanced',
                style: text.labelLarge?.copyWith(
                  color: TacticalPalette.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryCta(
          label: 'CONTINUE',
          onPressed: () => widget.onCompleted(FitnessLevel.values[_index]),
        ),
      ],
    );
  }
}

class _LevelSpec {
  const _LevelSpec({required this.label, required this.body});
  final String label;
  final String body;
}

/// Rank-insignia painter: four chevron stripes stacked bottom-to-top, growing
/// in width, filled up to [activeCount] with a bright arctic gradient and
/// drawn as thin outlines above that.
class _ChevronRank extends StatelessWidget {
  const _ChevronRank({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChevronRankPainter(activeCount: activeCount),
    );
  }
}

class _ChevronRankPainter extends CustomPainter {
  _ChevronRankPainter({required this.activeCount});

  final int activeCount;

  @override
  void paint(Canvas canvas, Size size) {
    const chevronCount = 4;
    const gap = 10.0;
    final availH = size.height;
    final chevronH = (availH - gap * (chevronCount - 1)) / chevronCount;

    for (int i = 0; i < chevronCount; i++) {
      // Bottom-up: widest chevron on top so bigger rank = broader stripe
      final rankFromBottom = i; // 0..3
      final active = rankFromBottom < activeCount;
      final widthFraction = 0.55 + rankFromBottom * 0.15; // 0.55 → 1.0
      final w = size.width * widthFraction;
      final centerX = size.width / 2;

      final top = availH - (rankFromBottom + 1) * chevronH -
          rankFromBottom * gap;
      final bottom = top + chevronH;
      // Chevron ^ shape — flat V pointing up
      final peakX = centerX;
      final peakY = top;
      final leftX = centerX - w / 2;
      final rightX = centerX + w / 2;
      final baseY = bottom;

      final path = Path()
        ..moveTo(leftX, baseY)
        ..lineTo(peakX, peakY)
        ..lineTo(rightX, baseY);

      if (active) {
        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TacticalPalette.glacier, TacticalPalette.arctic],
        ).createShader(Rect.fromLTWH(leftX, top, w, chevronH));
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = TacticalPalette.arctic.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(path, glowPaint);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = gradient;
        canvas.drawPath(path, paint);
      } else {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = TacticalPalette.hairline;
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChevronRankPainter old) =>
      old.activeCount != activeCount;
}

class _RankSlider extends StatelessWidget {
  const _RankSlider({
    required this.index,
    required this.count,
    required this.onChanged,
  });

  final int index;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: TacticalPalette.arctic,
        inactiveTrackColor: TacticalPalette.hairline,
        thumbColor: TacticalPalette.chalk,
        overlayColor: TacticalPalette.arctic.withValues(alpha: 0.15),
        activeTickMarkColor: TacticalPalette.chalk,
        inactiveTickMarkColor: TacticalPalette.muted.withValues(alpha: 0.6),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        min: 0,
        max: (count - 1).toDouble(),
        divisions: count - 1,
        value: index.toDouble(),
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}

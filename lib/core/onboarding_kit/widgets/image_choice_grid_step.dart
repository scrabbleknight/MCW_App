import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';

/// One option in an [ImageChoiceGridStep]. Extends [OnboardingOption] with a
/// `magnitude` value (0..1) used to draw a small pie-chart glyph in the
/// tile's corner — a "how much" visual for questions like sleep hours or
/// meals per day.
class MagnitudeOption<T> {
  const MagnitudeOption({
    required this.value,
    required this.label,
    required this.magnitude,
  });

  final T value;
  final String label;

  /// 0.0..1.0 — fraction of the pie glyph that's filled. 0.25 = quarter,
  /// 1.0 = fully filled.
  final double magnitude;
}

/// Question with a centered hero image card on top and a 2×2 grid of tiles
/// below. Each tile shows its label and a small pie-chart glyph in the
/// bottom-right whose fill matches [MagnitudeOption.magnitude]. Tap to
/// answer — the flow auto-advances via [onSelected].
class ImageChoiceGridStep<T> extends StatelessWidget {
  const ImageChoiceGridStep({
    super.key,
    required this.question,
    required this.imageAsset,
    required this.options,
    required this.onSelected,
    this.selected,
    this.columns = 2,
    this.tileAspectRatio = 2.4,
  });

  final String question;
  final String imageAsset;
  final List<MagnitudeOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final int columns;
  final double tileAspectRatio;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    ColoredBox(color: scheme.surface),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: tileAspectRatio,
          children: [
            for (final option in options)
              _MagnitudeTile(
                option: option,
                selected: option.value == selected,
                onTap: () => onSelected(option.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _MagnitudeTile<T> extends StatelessWidget {
  const _MagnitudeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MagnitudeOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final baseSurface = scheme.surfaceContainerHighest;
    final borderColor = selected ? scheme.primary : Colors.transparent;
    final fill = selected
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), baseSurface)
        : baseSurface;

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1.6),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 26,
                height: 26,
                child: CustomPaint(
                  painter: _PieGlyphPainter(
                    magnitude: option.magnitude,
                    fillColor: selected
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.55),
                    trackColor: scheme.onSurface.withValues(alpha: 0.22),
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

/// Draws a hollow circle track with a pie wedge starting at 12 o'clock,
/// filling clockwise up to [magnitude] of the circle.
class _PieGlyphPainter extends CustomPainter {
  _PieGlyphPainter({
    required this.magnitude,
    required this.fillColor,
    required this.trackColor,
  });

  final double magnitude;
  final Color fillColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1.4;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final clamped = magnitude.clamp(0.0, 1.0);
    if (clamped == 0) return;

    final wedge = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy - radius)
      ..addArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        clamped * math.pi * 2,
      )
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(wedge, Paint()..color = fillColor);
  }

  @override
  bool shouldRepaint(covariant _PieGlyphPainter old) =>
      old.magnitude != magnitude ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

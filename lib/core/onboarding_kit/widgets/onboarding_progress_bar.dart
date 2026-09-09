import 'package:flutter/material.dart';

/// Thin, minimal linear progress bar for onboarding flows.
///
/// [progress] is 0.0–1.0. Colors default to the current theme's primary +
/// a low-alpha version of it for the track, but both can be overridden.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.progress,
    this.trackColor,
    this.fillColor,
    this.height = 4,
  });

  final double progress;
  final Color? trackColor;
  final Color? fillColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = fillColor ?? scheme.primary;
    final track = trackColor ?? scheme.onSurface.withValues(alpha: 0.10);
    final clamped = progress.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: track),
          FractionallySizedBox(
            widthFactor: clamped == 0 ? 0.02 : clamped,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              height: height,
              color: fill,
            ),
          ),
        ],
      ),
    );
  }
}

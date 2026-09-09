import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';

/// Question with a full-height cut-out image behind, and single-select
/// option pills stacked in the top-left corner overlaid on top.
///
/// Designed for photos with a transparent background — the model reads as
/// standing in the app UI rather than being trapped in a card. Fits any
/// screen size because the image is aligned to bottom-right and clipped by
/// the parent bounds.
class OverlayChoiceSlide<T> extends StatelessWidget {
  const OverlayChoiceSlide({
    super.key,
    required this.question,
    required this.options,
    required this.imageAsset,
    required this.onSelected,
    this.selected,
    this.pillMaxWidthFraction = 0.55,
    this.imageHorizontalOffset = 0,
  });

  final String question;
  final List<OnboardingOption<T>> options;
  final String imageAsset;
  final T? selected;
  final ValueChanged<T> onSelected;

  /// Cap the option pills to this fraction of the parent width so they never
  /// bleed over the image — the model should always be readable behind them.
  final double pillMaxWidthFraction;

  /// Extra horizontal shift for the hero image, in logical pixels. Positive
  /// nudges her further right (some of the far edge clips off-screen);
  /// negative pulls her back toward the pills.
  final double imageHorizontalOffset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Woman fills the whole area — anchored bottom-right so
                  // she stands at the base of the frame, cropped naturally
                  // on the left when tighter than her width.
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(imageHorizontalOffset, 0),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: FractionallySizedBox(
                          heightFactor: 1.0,
                          child: Image.asset(
                            imageAsset,
                            fit: BoxFit.fitHeight,
                            alignment: Alignment.bottomRight,
                            errorBuilder: (context, error, stack) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Pills floated in the top-left, width-capped so they
                  // don't cover the model.
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SizedBox(
                      width: constraints.maxWidth * pillMaxWidthFraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in options) ...[
                            _OverlayPill(
                              label: option.label,
                              selected: option.value == selected,
                              onTap: () => onSelected(option.value),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final baseSurface = scheme.surfaceContainerHighest;
    final borderColor = selected ? scheme.primary : Colors.transparent;
    final fill = selected
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), baseSurface)
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            label,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

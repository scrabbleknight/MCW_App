import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';

/// Question with a stack of single-select option pills on the left and a
/// full-height decorative image on the right. Tapping a pill fires
/// [onSelected] with that value — the caller decides whether to advance.
///
/// The image is decoration only; interaction lives on the pills. Good fit
/// for questions where a body pose or portrait reinforces the ask.
class SplitChoiceSlide<T> extends StatelessWidget {
  const SplitChoiceSlide({
    super.key,
    required this.question,
    required this.options,
    required this.imageAsset,
    required this.onSelected,
    this.selected,
    this.optionsFlex = 5,
    this.imageFlex = 5,
  });

  final String question;
  final List<OnboardingOption<T>> options;
  final String imageAsset;
  final T? selected;
  final ValueChanged<T> onSelected;
  final int optionsFlex;
  final int imageFlex;

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: optionsFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options) ...[
                      _OptionPill(
                        label: option.label,
                        selected: option.value == selected,
                        onTap: () => onSelected(option.value),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: imageFlex,
                child: _DecorativeImage(assetPath: imageAsset),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
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

class _DecorativeImage extends StatelessWidget {
  const _DecorativeImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }
}

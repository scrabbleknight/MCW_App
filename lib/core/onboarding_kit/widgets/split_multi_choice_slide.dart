import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';
import 'primary_cta.dart';

/// Question with multi-select checkbox pills on the left, a decorative
/// image on the right, and a CONTINUE CTA at the bottom.
///
/// Ideal for a "which body zones" / "which muscle groups" step where the
/// image reinforces the concepts and the pills capture selections.
class SplitMultiChoiceSlide<T> extends StatefulWidget {
  const SplitMultiChoiceSlide({
    super.key,
    required this.question,
    required this.options,
    required this.imageAsset,
    required this.onCompleted,
    this.initialSelection = const {},
    this.helper = 'Choose all that apply',
    this.ctaLabel = 'CONTINUE',
    this.minSelection = 0,
    this.optionsFlex = 5,
    this.imageFlex = 5,
  });

  final String question;
  final String helper;
  final List<OnboardingOption<T>> options;
  final String imageAsset;
  final Set<T> initialSelection;
  final ValueChanged<Set<T>> onCompleted;
  final String ctaLabel;
  final int minSelection;
  final int optionsFlex;
  final int imageFlex;

  @override
  State<SplitMultiChoiceSlide<T>> createState() =>
      _SplitMultiChoiceSlideState<T>();
}

class _SplitMultiChoiceSlideState<T> extends State<SplitMultiChoiceSlide<T>> {
  late final Set<T> _picked = {...widget.initialSelection};

  void _toggle(T value) {
    setState(() {
      if (!_picked.remove(value)) _picked.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final canContinue = _picked.length >= widget.minSelection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.question,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.helper,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: widget.optionsFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in widget.options) ...[
                      _CheckPill(
                        label: option.label,
                        selected: _picked.contains(option.value),
                        onTap: () => _toggle(option.value),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: widget.imageFlex,
                child: Image.asset(
                  widget.imageAsset,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryCta(
          label: widget.ctaLabel,
          onPressed: () => widget.onCompleted(_picked),
          enabled: canContinue,
        ),
      ],
    );
  }
}

class _CheckPill extends StatelessWidget {
  const _CheckPill({
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
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Check(selected: selected, primary: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.primary});

  final bool selected;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? primary : Colors.transparent,
        border: Border.all(color: borderColor, width: 1.4),
        shape: BoxShape.circle,
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

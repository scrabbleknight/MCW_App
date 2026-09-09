import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';
import 'primary_cta.dart';

/// Question + list of options where any number can be picked. Includes its
/// own CONTINUE button; parent supplies [onCompleted] to advance the flow.
class MultiChoiceSlide<T> extends StatefulWidget {
  const MultiChoiceSlide({
    super.key,
    required this.question,
    required this.options,
    required this.onCompleted,
    this.initialSelection = const {},
    this.helper = 'Choose all that apply',
    this.ctaLabel = 'CONTINUE',
    this.minSelection = 0,
  });

  final String question;
  final String helper;
  final List<OnboardingOption<T>> options;
  final Set<T> initialSelection;
  final ValueChanged<Set<T>> onCompleted;
  final String ctaLabel;

  /// If > 0, CTA stays disabled until this many options are picked.
  final int minSelection;

  @override
  State<MultiChoiceSlide<T>> createState() => _MultiChoiceSlideState<T>();
}

class _MultiChoiceSlideState<T> extends State<MultiChoiceSlide<T>> {
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
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: widget.options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final option = widget.options[i];
              final selected = _picked.contains(option.value);
              return _MultiOptionTile(
                label: option.label,
                subtitle: option.subtitle,
                icon: option.icon,
                selected: selected,
                onTap: () => _toggle(option.value),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PrimaryCta(
          label: widget.ctaLabel,
          onPressed: () => widget.onCompleted(_picked),
          enabled: canContinue,
        ),
      ],
    );
  }
}

class _MultiOptionTile extends StatelessWidget {
  const _MultiOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
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
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: scheme.onSurface, size: 26),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _Checkbox(selected: selected, primary: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.selected, required this.primary});

  final bool selected;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? primary : Colors.transparent,
        border: Border.all(color: borderColor, width: 1.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : null,
    );
  }
}

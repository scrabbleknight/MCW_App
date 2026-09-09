import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';
import 'option_tile.dart';

/// Question + list of options, one selectable. Tapping an option calls
/// [onSelected] with its value; the slide advances externally on the same
/// call, so this widget stays stateless.
class SingleChoiceSlide<T> extends StatelessWidget {
  const SingleChoiceSlide({
    super.key,
    required this.question,
    required this.options,
    required this.onSelected,
    this.selectedValue,
    this.helper,
  });

  final String question;
  final String? helper;
  final List<OnboardingOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

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
        if (helper != null) ...[
          const SizedBox(height: 10),
          Text(
            helper!,
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final option = options[index];
              return OptionTile(
                label: option.label,
                subtitle: option.subtitle,
                icon: option.icon,
                selected: option.value == selectedValue,
                onTap: () => onSelected(option.value),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Two-segment pill for switching between measurement units (kg/lbs, ft/cm).
class UnitToggle<T> extends StatelessWidget {
  const UnitToggle({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<UnitToggleOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _Segment<T>(
              option: option,
              selected: option.value == value,
              onTap: () => onChanged(option.value),
              textStyle: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              selectedColor: scheme.primary,
              onSelected: scheme.onPrimary,
              onUnselected: scheme.onSurface.withValues(alpha: 0.55),
            ),
        ],
      ),
    );
  }
}

class UnitToggleOption<T> {
  const UnitToggleOption({required this.value, required this.label});
  final T value;
  final String label;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.textStyle,
    required this.selectedColor,
    required this.onSelected,
    required this.onUnselected,
  });

  final UnitToggleOption<T> option;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;
  final Color selectedColor;
  final Color onSelected;
  final Color onUnselected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Text(
            option.label,
            style: textStyle?.copyWith(
              color: selected ? onSelected : onUnselected,
            ),
          ),
        ),
      ),
    );
  }
}

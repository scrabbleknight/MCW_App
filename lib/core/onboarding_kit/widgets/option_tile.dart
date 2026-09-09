import 'package:flutter/material.dart';

/// Row-shaped selectable tile — icon left, label + optional subtitle right.
///
/// Used by single- and multi-choice onboarding slides. Selected state uses
/// the theme's primary color for the border; unselected uses the surface-high
/// container. Both tuck cleanly under a dark ground.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
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
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), baseSurface)
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              if (icon != null) ...[
                _IconChip(icon: icon!, selected: selected),
                const SizedBox(width: 18),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.6),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

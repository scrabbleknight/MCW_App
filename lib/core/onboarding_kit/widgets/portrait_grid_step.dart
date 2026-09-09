import 'package:flutter/material.dart';

/// One option in a [PortraitGridStep] — a portrait image with a label
/// underneath and a typed [value] that flows back to the caller on tap.
class PortraitOption<T> {
  const PortraitOption({
    required this.value,
    required this.label,
    required this.imageAsset,
  });

  final T value;
  final String label;
  final String imageAsset;
}

/// Where the tile's label sits within a [PortraitGridStep] card.
///
/// [PortraitLabelPlacement.belowImage] — image on top, label in a padded
/// footer beneath it (default; used for age-picker headshots).
/// [PortraitLabelPlacement.topLeftOverlay] — image fills the whole tile,
/// label overlaid as a chip in the top-left (used for body-shape grids).
enum PortraitLabelPlacement { belowImage, topLeftOverlay }

/// Grid of portrait tiles, single-select. Ideal for age band, gender,
/// body-type, or coach-picker steps in a health/fitness onboarding.
///
/// Layout: title + optional subtitle at the top, then a scrollable grid of
/// [options]. Tap a tile → [onSelected] fires with its value; the caller
/// decides whether to auto-advance the flow.
class PortraitGridStep<T> extends StatelessWidget {
  const PortraitGridStep({
    super.key,
    required this.title,
    required this.options,
    required this.onSelected,
    this.subtitle,
    this.selected,
    this.columns = 2,
    this.tileAspectRatio = 0.82,
    this.labelPlacement = PortraitLabelPlacement.belowImage,
  });

  final String title;
  final String? subtitle;
  final List<PortraitOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final int columns;
  final double tileAspectRatio;
  final PortraitLabelPlacement labelPlacement;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: tileAspectRatio,
            ),
            itemCount: options.length,
            itemBuilder: (context, i) {
              final option = options[i];
              return _PortraitTile(
                option: option,
                selected: option.value == selected,
                onTap: () => onSelected(option.value),
                placement: labelPlacement,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PortraitTile<T> extends StatelessWidget {
  const _PortraitTile({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.placement,
  });

  final PortraitOption<T> option;
  final bool selected;
  final VoidCallback onTap;
  final PortraitLabelPlacement placement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final baseSurface = scheme.surfaceContainerHighest;
    final borderColor = selected ? scheme.primary : Colors.transparent;
    final fill = selected
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), baseSurface)
        : baseSurface;

    final image = Image.asset(
      option.imageAsset,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stack) =>
          ColoredBox(color: scheme.surface),
    );

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1.6),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: switch (placement) {
          PortraitLabelPlacement.belowImage => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: image),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          PortraitLabelPlacement.topLeftOverlay => Stack(
              fit: StackFit.expand,
              children: [
                image,
                Positioned(
                  top: 12,
                  left: 14,
                  child: Text(
                    option.label,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
}

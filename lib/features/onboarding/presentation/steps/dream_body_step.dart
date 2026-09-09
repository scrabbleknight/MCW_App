import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum DreamBody { slim, average, curvy, toned }

/// Eighth onboarding step — pick the target body shape. 2×2 grid of body
/// photos with the label overlaid top-left; tap auto-advances the flow.
class DreamBodyStep extends StatelessWidget {
  const DreamBodyStep({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DreamBody? selected;
  final ValueChanged<DreamBody> onSelected;

  @override
  Widget build(BuildContext context) {
    return PortraitGridStep<DreamBody>(
      title: 'How would you describe your physical build?',
      subtitle: null,
      selected: selected,
      onSelected: onSelected,
      tileAspectRatio: 0.78,
      labelPlacement: PortraitLabelPlacement.topLeftOverlay,
      options: const [
        PortraitOption(
          value: DreamBody.slim,
          label: 'Skinny',
          imageAsset: 'assets/branding/body_type_1.png',
        ),
        PortraitOption(
          value: DreamBody.average,
          label: 'Mid-sized',
          imageAsset: 'assets/branding/body_type_2.png',
        ),
        PortraitOption(
          value: DreamBody.curvy,
          label: 'Plus-sized',
          imageAsset: 'assets/branding/body_type_3.png',
        ),
        PortraitOption(
          value: DreamBody.toned,
          label: 'Overweight',
          imageAsset: 'assets/branding/body_type_4.png',
        ),
      ],
    );
  }
}

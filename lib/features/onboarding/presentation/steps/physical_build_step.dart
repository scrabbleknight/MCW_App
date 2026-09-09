import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum PhysicalBuild { skinny, midSized, plusSized, overweight }

/// Ninth onboarding step — pick current physical build. Same 2×2 layout as
/// [DreamBodyStep]; used together to calibrate the plan's difficulty ramp.
class PhysicalBuildStep extends StatelessWidget {
  const PhysicalBuildStep({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PhysicalBuild? selected;
  final ValueChanged<PhysicalBuild> onSelected;

  @override
  Widget build(BuildContext context) {
    return PortraitGridStep<PhysicalBuild>(
      title: "What's your dream body?",
      subtitle: 'Visualize your goal to stay motivated and accountable',
      selected: selected,
      onSelected: onSelected,
      tileAspectRatio: 0.78,
      labelPlacement: PortraitLabelPlacement.topLeftOverlay,
      options: const [
        PortraitOption(
          value: PhysicalBuild.skinny,
          label: 'Slim',
          imageAsset: 'assets/branding/body_type_5.png',
        ),
        PortraitOption(
          value: PhysicalBuild.midSized,
          label: 'Average',
          imageAsset: 'assets/branding/body_type_6.png',
        ),
        PortraitOption(
          value: PhysicalBuild.plusSized,
          label: 'Curvy',
          imageAsset: 'assets/branding/body_type_7.png',
        ),
        PortraitOption(
          value: PhysicalBuild.overweight,
          label: 'Toned',
          imageAsset: 'assets/branding/body_type_8.png',
        ),
      ],
    );
  }
}

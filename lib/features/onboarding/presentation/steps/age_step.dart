import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum AgeBand { under18, from18to24, from25to34, from35to44, from45to54, over55 }

/// Fourth onboarding step — pick an age band. Each tile pairs a woman's
/// portrait with the band label; tap advances the flow.
class AgeStep extends StatelessWidget {
  const AgeStep({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AgeBand? selected;
  final ValueChanged<AgeBand> onSelected;

  @override
  Widget build(BuildContext context) {
    return PortraitGridStep<AgeBand>(
      title: 'Military Calisthenics Plan',
      subtitle: 'Based on your Age',
      selected: selected,
      onSelected: onSelected,
      options: const [
        PortraitOption(
          value: AgeBand.under18,
          label: '<18',
          imageAsset: 'assets/branding/profile1.png',
        ),
        PortraitOption(
          value: AgeBand.from18to24,
          label: '18~24',
          imageAsset: 'assets/branding/profile2.png',
        ),
        PortraitOption(
          value: AgeBand.from25to34,
          label: '25~34',
          imageAsset: 'assets/branding/profile3.png',
        ),
        PortraitOption(
          value: AgeBand.from35to44,
          label: '35~44',
          imageAsset: 'assets/branding/profile4.png',
        ),
        PortraitOption(
          value: AgeBand.from45to54,
          label: '45~54',
          imageAsset: 'assets/branding/profile5.png',
        ),
        PortraitOption(
          value: AgeBand.over55,
          label: '55+',
          imageAsset: 'assets/branding/profile6.png',
        ),
      ],
    );
  }
}

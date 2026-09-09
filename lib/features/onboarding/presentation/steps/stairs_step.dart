import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum StairsFeel { veryOut, slightlyOut, okAfterOne, fineMultiple }

/// Overlay-layout step — self-assessed cardio load on stairs. Uses the
/// marching-pose ginger cutout on the right.
class StairsStep extends StatelessWidget {
  const StairsStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final StairsFeel? selected;
  final ValueChanged<StairsFeel> onAnswered;

  @override
  Widget build(BuildContext context) {
    return OverlayChoiceSlide<StairsFeel>(
      question: 'How do you feel when climbing the stairs?',
      imageAsset: 'assets/branding/onboarding_hero_11_transparent.png',
      selected: selected,
      onSelected: onAnswered,
      pillMaxWidthFraction: 0.44,
      options: const [
        OnboardingOption(
          value: StairsFeel.veryOut,
          label: 'Very out of breath',
        ),
        OnboardingOption(
          value: StairsFeel.slightlyOut,
          label: 'Slightly out of breath',
        ),
        OnboardingOption(
          value: StairsFeel.okAfterOne,
          label: 'OK after one flight',
        ),
        OnboardingOption(
          value: StairsFeel.fineMultiple,
          label: 'Fine after multiple flights',
        ),
      ],
    );
  }
}

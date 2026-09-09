import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum WaterIntake { coffeeOnly, aboutTwo, twoToSix, moreThanSix }

/// Overlay-layout question — daily hydration. Ginger cutout with water
/// bottle on the right, option pills on the left.
class WaterIntakeStep extends StatelessWidget {
  const WaterIntakeStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final WaterIntake? selected;
  final ValueChanged<WaterIntake> onAnswered;

  @override
  Widget build(BuildContext context) {
    return OverlayChoiceSlide<WaterIntake>(
      question: 'How much water do you drink daily?',
      imageAsset: 'assets/branding/onboarding_hero_14_transparent.png',
      selected: selected,
      onSelected: onAnswered,
      pillMaxWidthFraction: 0.44,
      options: const [
        OnboardingOption(
          value: WaterIntake.coffeeOnly,
          label: 'I only have coffee or tea',
        ),
        OnboardingOption(
          value: WaterIntake.aboutTwo,
          label: 'About 2 glasses',
        ),
        OnboardingOption(
          value: WaterIntake.twoToSix,
          label: '2 to 6 glasses',
        ),
        OnboardingOption(
          value: WaterIntake.moreThanSix,
          label: 'More than 6 glasses',
        ),
      ],
    );
  }
}

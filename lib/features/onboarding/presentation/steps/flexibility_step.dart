import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum Flexibility { prettyFlexible, justStarting, notThatGood, notSure }

/// Thirteenth onboarding step — self-assessed flexibility. Same overlay
/// layout as [BestShapeStep]: pills float top-left, the ginger tactical
/// model stretches full-height on the right.
class FlexibilityStep extends StatelessWidget {
  const FlexibilityStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final Flexibility? selected;
  final ValueChanged<Flexibility> onAnswered;

  @override
  Widget build(BuildContext context) {
    return OverlayChoiceSlide<Flexibility>(
      question: 'How flexible are you?',
      imageAsset: 'assets/branding/onboarding_hero_10_transparent.png',
      selected: selected,
      onSelected: onAnswered,
      pillMaxWidthFraction: 0.44,
      options: const [
        OnboardingOption(
          value: Flexibility.prettyFlexible,
          label: 'Pretty flexible',
        ),
        OnboardingOption(
          value: Flexibility.justStarting,
          label: 'Just getting started',
        ),
        OnboardingOption(
          value: Flexibility.notThatGood,
          label: 'Not that good',
        ),
        OnboardingOption(
          value: Flexibility.notSure,
          label: 'Not sure',
        ),
      ],
    );
  }
}

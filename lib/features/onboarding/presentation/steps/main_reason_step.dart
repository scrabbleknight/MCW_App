import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum MainReason {
  confidence,
  healthAndEnergy,
  fitInClothes,
  postpartum,
  other,
}

/// Single-select — the user's core motivation. Feeds coaching-copy tone and
/// which milestones the plan highlights.
class MainReasonStep extends StatelessWidget {
  const MainReasonStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final MainReason? selected;
  final ValueChanged<MainReason> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<MainReason>(
      question: "What's your main reason to get in shape?",
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: MainReason.confidence,
          label: 'Feel more confident in my body',
        ),
        OnboardingOption(
          value: MainReason.healthAndEnergy,
          label: 'Feel healthier and more energetic',
        ),
        OnboardingOption(
          value: MainReason.fitInClothes,
          label: 'Fit in my clothes better',
        ),
        OnboardingOption(
          value: MainReason.postpartum,
          label: 'Get back in shape after giving birth',
        ),
        OnboardingOption(
          value: MainReason.other,
          label: 'Other',
        ),
      ],
    );
  }
}

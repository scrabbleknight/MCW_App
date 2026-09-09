import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum WeightPattern { gainFastLoseSlow, gainAndLoseEasily, struggleToGain }

/// Tenth onboarding step — text-only single choice describing typical
/// weight/muscle dynamics. Auto-advances on tap.
class WeightChangeStep extends StatelessWidget {
  const WeightChangeStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final WeightPattern? selected;
  final ValueChanged<WeightPattern> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<WeightPattern>(
      question: 'How does your weight typically change?',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: WeightPattern.gainFastLoseSlow,
          label: 'I gain weight fast but lose it slowly',
        ),
        OnboardingOption(
          value: WeightPattern.gainAndLoseEasily,
          label: 'I gain and lose weight easily',
        ),
        OnboardingOption(
          value: WeightPattern.struggleToGain,
          label: 'I struggle to gain weight or muscle',
        ),
      ],
    );
  }
}

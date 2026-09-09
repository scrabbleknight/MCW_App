import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum FoodCraving { sweetTreats, saltySnacks, fastFood, soda, none }

/// Multi-select — foods the user craves most often.
class FoodCravingsStep extends StatelessWidget {
  const FoodCravingsStep({
    super.key,
    required this.initialSelection,
    required this.onCompleted,
  });

  final Set<FoodCraving> initialSelection;
  final ValueChanged<Set<FoodCraving>> onCompleted;

  @override
  Widget build(BuildContext context) {
    return MultiChoiceSlide<FoodCraving>(
      question: 'What foods do you crave most often?',
      initialSelection: initialSelection,
      onCompleted: onCompleted,
      minSelection: 1,
      options: const [
        OnboardingOption(value: FoodCraving.sweetTreats, label: 'Sweet treats'),
        OnboardingOption(value: FoodCraving.saltySnacks, label: 'Salty snacks'),
        OnboardingOption(value: FoodCraving.fastFood, label: 'Fast food'),
        OnboardingOption(value: FoodCraving.soda, label: 'Soda'),
        OnboardingOption(value: FoodCraving.none, label: 'None of the above'),
      ],
    );
  }
}

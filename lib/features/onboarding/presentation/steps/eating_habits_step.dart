import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum EatingHabit {
  emotionalEating,
  overeating,
  lateNightSnacking,
  skippingMeals,
  none,
}

/// Multi-select — self-reported eating habits. "None of the above" is
/// mutually exclusive with the other options.
class EatingHabitsStep extends StatelessWidget {
  const EatingHabitsStep({
    super.key,
    required this.initialSelection,
    required this.onCompleted,
  });

  final Set<EatingHabit> initialSelection;
  final ValueChanged<Set<EatingHabit>> onCompleted;

  @override
  Widget build(BuildContext context) {
    return MultiChoiceSlide<EatingHabit>(
      question: 'Do you have any of these habits?',
      initialSelection: initialSelection,
      onCompleted: onCompleted,
      minSelection: 1,
      options: const [
        OnboardingOption(
          value: EatingHabit.emotionalEating,
          label: 'Emotional or boredom eating',
        ),
        OnboardingOption(
          value: EatingHabit.overeating,
          label: 'Overeating',
        ),
        OnboardingOption(
          value: EatingHabit.lateNightSnacking,
          label: 'Late-night snacking',
        ),
        OnboardingOption(
          value: EatingHabit.skippingMeals,
          label: 'Skipping meals too often',
        ),
        OnboardingOption(
          value: EatingHabit.none,
          label: 'None of the above',
        ),
      ],
    );
  }
}

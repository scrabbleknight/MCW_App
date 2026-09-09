import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum DietType { traditional, keto, paleo, vegetarian, vegan, ketoVegan }

/// Single-choice — preferred diet style, with descriptive subtitles.
class DietTypeStep extends StatelessWidget {
  const DietTypeStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final DietType? selected;
  final ValueChanged<DietType> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<DietType>(
      question: 'What type of diet do you prefer?',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: DietType.traditional,
          label: 'Traditional',
          subtitle: 'I enjoy everything',
        ),
        OnboardingOption(
          value: DietType.keto,
          label: 'Keto',
          subtitle: 'I prefer high-fat low-carb meals',
        ),
        OnboardingOption(
          value: DietType.paleo,
          label: 'Paleo',
          subtitle: "I don't eat processed foods",
        ),
        OnboardingOption(
          value: DietType.vegetarian,
          label: 'Vegetarian',
          subtitle: 'I avoid meat and fish',
        ),
        OnboardingOption(
          value: DietType.vegan,
          label: 'Vegan (Plant Diet)',
          subtitle: 'I do not eat animal products',
        ),
        OnboardingOption(
          value: DietType.ketoVegan,
          label: 'Keto Vegan',
          subtitle: 'I eat low-carb plant-based meals only',
        ),
      ],
    );
  }
}

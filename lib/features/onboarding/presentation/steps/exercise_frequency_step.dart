import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum ExerciseFrequency { daily, weekly, monthly, never }

/// Overlay-layout step — how often the user works out. Uses the side-lunge
/// ginger cutout on the right.
class ExerciseFrequencyStep extends StatelessWidget {
  const ExerciseFrequencyStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final ExerciseFrequency? selected;
  final ValueChanged<ExerciseFrequency> onAnswered;

  @override
  Widget build(BuildContext context) {
    return OverlayChoiceSlide<ExerciseFrequency>(
      question: 'How often do you exercise?',
      imageAsset: 'assets/branding/onboarding_hero_12_transparent.png',
      selected: selected,
      onSelected: onAnswered,
      pillMaxWidthFraction: 0.44,
      imageHorizontalOffset: 40,
      options: const [
        OnboardingOption(
          value: ExerciseFrequency.daily,
          label: 'Almost every day',
        ),
        OnboardingOption(
          value: ExerciseFrequency.weekly,
          label: 'Several times a week',
        ),
        OnboardingOption(
          value: ExerciseFrequency.monthly,
          label: 'Several times a month',
        ),
        OnboardingOption(
          value: ExerciseFrequency.never,
          label: 'Never',
        ),
      ],
    );
  }
}

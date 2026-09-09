import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum WorkoutDuration { under10, tenToFifteen, fifteenToTwenty, twentyToThirty }

/// Text-only single choice — target session length. Drives how the plan
/// stacks blocks per day.
class WorkoutDurationStep extends StatelessWidget {
  const WorkoutDurationStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final WorkoutDuration? selected;
  final ValueChanged<WorkoutDuration> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<WorkoutDuration>(
      question: 'How long would you like to spend on each workout?',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: WorkoutDuration.under10,
          label: 'Under 10 minutes',
        ),
        OnboardingOption(
          value: WorkoutDuration.tenToFifteen,
          label: '10-15 minutes',
        ),
        OnboardingOption(
          value: WorkoutDuration.fifteenToTwenty,
          label: '15-20 minutes',
        ),
        OnboardingOption(
          value: WorkoutDuration.twentyToThirty,
          label: '20-30 minutes',
        ),
      ],
    );
  }
}

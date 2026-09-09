import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum WorkoutPreference {
  noPreferences,
  allStanding,
  noSquat,
  noJumping,
  noProne,
  noKneeling,
}

/// Single-select movement filter for the plan. First option ("No Preferences")
/// is the recommended path and carries a subtitle explaining what happens
/// when it's chosen; the rest are mutually exclusive movement restrictions.
class WorkoutPreferencesStep extends StatelessWidget {
  const WorkoutPreferencesStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final WorkoutPreference? selected;
  final ValueChanged<WorkoutPreference> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<WorkoutPreference>(
      question: 'Any workout preferences to note?',
      helper: 'You can always change this later',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: WorkoutPreference.noPreferences,
          label: 'No Preferences',
          subtitle: 'Follow our recommended plan, optimized for your goals.',
          icon: Icons.auto_awesome_rounded,
        ),
        OnboardingOption(
          value: WorkoutPreference.allStanding,
          label: 'All Standing',
        ),
        OnboardingOption(
          value: WorkoutPreference.noSquat,
          label: 'No Squat',
        ),
        OnboardingOption(
          value: WorkoutPreference.noJumping,
          label: 'No Jumping',
        ),
        OnboardingOption(
          value: WorkoutPreference.noProne,
          label: 'No Prone',
        ),
        OnboardingOption(
          value: WorkoutPreference.noKneeling,
          label: 'No Kneeling',
        ),
      ],
    );
  }
}

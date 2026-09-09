import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum FitnessGoal { loseWeight, maintainAndFit, buildStrength, recomp }

/// Fifth onboarding step — pick a primary fitness goal. Drives the plan
/// recommendation later. Tapping an option auto-advances the flow.
class GoalStep extends StatelessWidget {
  const GoalStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final FitnessGoal? selected;
  final ValueChanged<FitnessGoal> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<FitnessGoal>(
      question: "What's your main goal?",
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: FitnessGoal.loseWeight,
          label: 'Lose weight',
          icon: Icons.monitor_weight_outlined,
        ),
        OnboardingOption(
          value: FitnessGoal.maintainAndFit,
          label: 'Maintain weight and get fit',
          icon: Icons.monitor_heart_outlined,
        ),
        OnboardingOption(
          value: FitnessGoal.buildStrength,
          label: 'Build muscles and strength',
          icon: Icons.fitness_center_rounded,
        ),
        OnboardingOption(
          value: FitnessGoal.recomp,
          label: 'Gain muscle and lose weight',
          icon: Icons.accessibility_new_rounded,
        ),
      ],
    );
  }
}

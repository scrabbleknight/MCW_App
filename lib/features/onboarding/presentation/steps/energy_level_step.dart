import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum EnergyLevel { low, postLunchSlump, draggingBeforeMeals, highSteady }

/// Text-only single choice — daytime energy self-assessment. Feeds the plan's
/// pacing recommendation later.
class EnergyLevelStep extends StatelessWidget {
  const EnergyLevelStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final EnergyLevel? selected;
  final ValueChanged<EnergyLevel> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<EnergyLevel>(
      question: 'How are your energy levels during the day?',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: EnergyLevel.low,
          label: 'Low, I feel tired throughout the day',
        ),
        OnboardingOption(
          value: EnergyLevel.postLunchSlump,
          label: 'Post-lunch slump',
        ),
        OnboardingOption(
          value: EnergyLevel.draggingBeforeMeals,
          label: 'Dragging before meals',
        ),
        OnboardingOption(
          value: EnergyLevel.highSteady,
          label: 'High and steady',
        ),
      ],
    );
  }
}

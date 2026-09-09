import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum PriorExperience { yes, no }

class ExperienceStep extends StatelessWidget {
  const ExperienceStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final PriorExperience? selected;
  final ValueChanged<PriorExperience> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<PriorExperience>(
      question: 'Have you tried military\ncalisthenics before?',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: PriorExperience.yes,
          label: 'Yes',
          icon: Icons.check_rounded,
        ),
        OnboardingOption(
          value: PriorExperience.no,
          label: 'No',
          icon: Icons.block_rounded,
        ),
      ],
    );
  }
}

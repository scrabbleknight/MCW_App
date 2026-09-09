import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum Achievement {
  toning,
  posture,
  metabolism,
  flexibility,
  confidence,
}

/// Seventh onboarding step — multi-select "what else do you hope to achieve"
/// question. Any number of goals can be picked; CONTINUE always advances.
class AchievementsStep extends StatelessWidget {
  const AchievementsStep({
    super.key,
    required this.initialSelection,
    required this.onCompleted,
  });

  final Set<Achievement> initialSelection;
  final ValueChanged<Set<Achievement>> onCompleted;

  @override
  Widget build(BuildContext context) {
    return MultiChoiceSlide<Achievement>(
      question: 'What else do you hope to achieve with this plan?',
      initialSelection: initialSelection,
      onCompleted: onCompleted,
      options: const [
        OnboardingOption(
          value: Achievement.toning,
          label: 'Body Toning & Sculpting',
          icon: Icons.emoji_people_rounded,
        ),
        OnboardingOption(
          value: Achievement.posture,
          label: 'Posture Improvement',
          icon: Icons.accessibility_new_rounded,
        ),
        OnboardingOption(
          value: Achievement.metabolism,
          label: 'Boost Metabolism',
          icon: Icons.local_fire_department_rounded,
        ),
        OnboardingOption(
          value: Achievement.flexibility,
          label: 'Improve Flexibility & Mobility',
          icon: Icons.self_improvement_rounded,
        ),
        OnboardingOption(
          value: Achievement.confidence,
          label: 'Confidence & Body Awareness',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
  }
}

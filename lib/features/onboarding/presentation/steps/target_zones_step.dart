import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum TargetZone { fullBody, back, arms, belly, butt, legs }

/// Twelfth onboarding step — multi-select body zones the user wants to
/// focus on. Split layout: pills with checkboxes on the left, the ginger
/// tactical model (with baked-in callout art) on the right, CONTINUE below.
class TargetZonesStep extends StatelessWidget {
  const TargetZonesStep({
    super.key,
    required this.initialSelection,
    required this.onCompleted,
  });

  final Set<TargetZone> initialSelection;
  final ValueChanged<Set<TargetZone>> onCompleted;

  @override
  Widget build(BuildContext context) {
    return SplitMultiChoiceSlide<TargetZone>(
      question: 'What are your target zones?',
      imageAsset: 'assets/branding/onboarding_hero_15.png',
      initialSelection: initialSelection,
      onCompleted: onCompleted,
      options: const [
        OnboardingOption(value: TargetZone.fullBody, label: 'Fullbody'),
        OnboardingOption(value: TargetZone.back, label: 'Back'),
        OnboardingOption(value: TargetZone.arms, label: 'Arms'),
        OnboardingOption(value: TargetZone.belly, label: 'Belly'),
        OnboardingOption(value: TargetZone.butt, label: 'Butt'),
        OnboardingOption(value: TargetZone.legs, label: 'Legs'),
      ],
    );
  }
}

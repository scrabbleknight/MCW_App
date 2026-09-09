import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

/// Statement page — reinforces the benefit before diving into the next
/// battery of self-assessment questions. No input, just a Continue.
class EnergizedStep extends StatelessWidget {
  const EnergizedStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return StatementImageSlide(
      title: 'Calisthenics will help you feel more energized',
      paragraphs: const [
        'These workouts will strengthen your muscles, and increase endurance.',
        "You'll have more energy to keep up with your daily activities.",
      ],
      imageAsset: 'assets/branding/onboarding_hero_13_transparent.png',
      onContinue: onContinue,
    );
  }
}

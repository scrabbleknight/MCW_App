import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum SleepHours { under5, fiveToSix, sevenToEight, moreThanEight }

/// Image-header + 2×2 grid step — typical nightly sleep. Each tile carries a
/// pie glyph showing "how much" so the answers read at a glance.
class SleepHoursStep extends StatelessWidget {
  const SleepHoursStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final SleepHours? selected;
  final ValueChanged<SleepHours> onAnswered;

  @override
  Widget build(BuildContext context) {
    return ImageChoiceGridStep<SleepHours>(
      question: 'How much sleep do you usually get?',
      imageAsset: 'assets/branding/onboarding_hero_15.png',
      selected: selected,
      onSelected: onAnswered,
      options: const [
        MagnitudeOption(
          value: SleepHours.under5,
          label: 'Less than 5 hours',
          magnitude: 0.25,
        ),
        MagnitudeOption(
          value: SleepHours.fiveToSix,
          label: '5-6 hours',
          magnitude: 0.5,
        ),
        MagnitudeOption(
          value: SleepHours.sevenToEight,
          label: '7-8 hours',
          magnitude: 0.75,
        ),
        MagnitudeOption(
          value: SleepHours.moreThanEight,
          label: 'More than 8 hours',
          magnitude: 1.0,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum MealsPerDay { one, two, three, fourPlus }

/// Image-header + 2×2 grid step — meals per day. Same magnitude-glyph
/// layout as [SleepHoursStep].
class MealsPerDayStep extends StatelessWidget {
  const MealsPerDayStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final MealsPerDay? selected;
  final ValueChanged<MealsPerDay> onAnswered;

  @override
  Widget build(BuildContext context) {
    return ImageChoiceGridStep<MealsPerDay>(
      question: 'How many meals do you typically have in a day?',
      imageAsset: 'assets/branding/onboarding_hero_17.png',
      selected: selected,
      onSelected: onAnswered,
      options: const [
        MagnitudeOption(
          value: MealsPerDay.one,
          label: '1 meal',
          magnitude: 0.25,
        ),
        MagnitudeOption(
          value: MealsPerDay.two,
          label: '2 meals',
          magnitude: 0.5,
        ),
        MagnitudeOption(
          value: MealsPerDay.three,
          label: '3 meals',
          magnitude: 0.75,
        ),
        MagnitudeOption(
          value: MealsPerDay.fourPlus,
          label: '4 / 4+ meals',
          magnitude: 1.0,
        ),
      ],
    );
  }
}

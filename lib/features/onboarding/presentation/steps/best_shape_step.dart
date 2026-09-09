import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum BestShape { lessThanYear, oneToTwoYears, moreThanThreeYears, never }

/// Eleventh onboarding step — pick how long ago the user was in their best
/// physical shape. The ginger tactical model stands full-height behind the
/// option pills (transparent-background asset), pills floated top-left.
class BestShapeStep extends StatelessWidget {
  const BestShapeStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final BestShape? selected;
  final ValueChanged<BestShape> onAnswered;

  @override
  Widget build(BuildContext context) {
    return OverlayChoiceSlide<BestShape>(
      question: 'How long ago were you in the best shape of your life?',
      imageAsset: 'assets/branding/onboarding_hero_8_transparent.png',
      selected: selected,
      onSelected: onAnswered,
      pillMaxWidthFraction: 0.44,
      options: const [
        OnboardingOption(
          value: BestShape.lessThanYear,
          label: 'Less than a year ago',
        ),
        OnboardingOption(
          value: BestShape.oneToTwoYears,
          label: '1 to 2 years ago',
        ),
        OnboardingOption(
          value: BestShape.moreThanThreeYears,
          label: 'More than 3 years ago',
        ),
        OnboardingOption(
          value: BestShape.never,
          label: 'Never',
        ),
      ],
    );
  }
}

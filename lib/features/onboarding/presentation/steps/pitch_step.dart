import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

/// Third onboarding step — three-slide carousel selling why bodyweight
/// tactical calisthenics is the right fit. Copy is women-facing and stays
/// in the tactical/blue voice; images come from the pre-installed hero pack.
class PitchStep extends StatelessWidget {
  const PitchStep({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return PitchCarouselStep(
      title: 'Calisthenics is an easy and effective fitness option!',
      onCompleted: onCompleted,
      slides: const [
        PitchSlide(
          imageAsset: 'assets/branding/onboarding_hero_2.png',
          heading: 'Strong AND sculpted',
          body: '—build real power while your lines lock in tight.',
        ),
        PitchSlide(
          imageAsset: 'assets/branding/onboarding_hero_3.png',
          heading: 'Meets you where you are',
          body: '—first pushup or full pistol, the plan scales to you.',
        ),
        PitchSlide(
          imageAsset: 'assets/branding/onboarding_hero_4.png',
          heading: 'Zero gear, zero excuses',
          body: '—train anywhere. Bedroom floor, hotel room, park.',
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

/// Sixth onboarding step — auto-cycling social-proof carousel with three
/// tactical-flavour testimonials, each anchored by a before / after image.
class TestimonialsStep extends StatelessWidget {
  const TestimonialsStep({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return TestimonialCarouselStep(
      title: 'We know how to make that happen!',
      subtitle:
          'Real results from real women. The programme scales to where you '
          "are — no gym, no gear, just consistent bodyweight work.",
      onCompleted: onCompleted,
      testimonials: const [
        Testimonial(
          imageAsset: 'assets/branding/onboarding_hero_5.png',
          afterLabel: 'Day 45',
          title: 'Feeling unstoppable',
          body:
              'Six weeks in and I can knock out unassisted pull-ups. Never '
              'touched a barbell — this all came from bodyweight training in '
              'my living room.',
        ),
        Testimonial(
          imageAsset: 'assets/branding/onboarding_hero_6.png',
          afterLabel: 'Day 28',
          title: 'Down 12 kg, up in strength',
          body:
              'The plan scaled to me on day one and kept pushing. Fifteen '
              'minutes a day, no gym, and my body kept surprising me week '
              'after week.',
        ),
        Testimonial(
          imageAsset: 'assets/branding/onboarding_hero_7.png',
          afterLabel: 'Day 28',
          title: 'Confidence I forgot I had',
          body:
              'I signed up nervous about starting from zero. Two months in '
              'and I show up for every session. The tactical structure '
              'actually kept me consistent.',
        ),
      ],
    );
  }
}

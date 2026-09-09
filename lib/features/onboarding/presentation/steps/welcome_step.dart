import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.onContinue,
    required this.onLogIn,
  });

  final VoidCallback onContinue;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Broad, industrial-athletic display face — sits closer to the reference
    // than the system sans and reads as "military poster" without a bespoke
    // font file. Swap the family in one place if this app's brand changes.
    final titleStyle = GoogleFonts.bigShouldersDisplay(
      fontWeight: FontWeight.w900,
      color: TacticalPalette.chalk,
      height: 0.88,
      letterSpacing: 1.2,
      fontSize: 68,
    );

    return HeroIntroSlide(
      imageAsset: 'assets/branding/onboarding_hero_1.2.png',
      // Asset already ships with a real alpha channel — skip the runtime
      // black-to-alpha colour-matrix fallback for a pixel-perfect cutout.
      dropBlackBackground: false,
      imageVerticalOffset: 40,
      imageHorizontalOffset: -30,
      title: 'TACTICAL\nCALISTHENICS',
      subhead: 'Train harder.\nStart anywhere.',
      tagline: 'Build strength at any level—one step at a time.',
      statHeadline: '25 Million+',
      statCaption: 'Women started their strength journey with us.',
      primaryCtaLabel: 'Start Now',
      onPrimaryCta: onContinue,
      onLogIn: onLogIn,
      overlayColor: TacticalPalette.abyss,
      titleTextStyle: titleStyle,
      // Hand-designed blue-camo backdrop, provided as an asset — richer than
      // the procedural [CamoBackground] painter (kept in the kit for future
      // apps that don't ship one).
      background: Image.asset(
        'assets/branding/camo_background.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
      termsRich: Text.rich(
        TextSpan(
          text: 'By continuing you agree to the ',
          style: text.bodySmall?.copyWith(color: TacticalPalette.muted),
          children: [
            TextSpan(
              text: 'Privacy Policy',
              style: text.bodySmall?.copyWith(
                color: TacticalPalette.arcticSoft,
                decoration: TextDecoration.underline,
                decorationColor: TacticalPalette.arcticSoft,
              ),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Terms of Use',
              style: text.bodySmall?.copyWith(
                color: TacticalPalette.arcticSoft,
                decoration: TextDecoration.underline,
                decorationColor: TacticalPalette.arcticSoft,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

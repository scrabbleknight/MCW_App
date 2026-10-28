import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:military_calisthenics_women/core/funnel/analytics_consent_sheet.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

/// Whether this phone's region (EU/EEA, or none) needs people to agree
/// before analytics starts ([AnalyticsAgreement.needed]). Read through the
/// binding, which is the same dispatcher in the app and the one widget
/// tests can set a region on.
bool welcomeNeedsAgreement() => AnalyticsAgreement.needed(
  WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? '',
);

/// Welcome's button, which goes on and turns analytics on. In the EU/EEA
/// it says so: "AGREE AND CONTINUE" (upper-case like the app's other
/// buttons). Elsewhere it keeps "Start Now".
String welcomeCtaLabel({bool? agreementNeeded}) =>
    (agreementNeeded ?? welcomeNeedsAgreement())
    ? 'AGREE AND CONTINUE'
    : 'Start Now';

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
    // The camo backdrop is dark in both themes, so the text over it is
    // always white rather than following the theme's (dark-in-light-mode)
    // text colour.
    final titleStyle = GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 0.88,
      letterSpacing: 1.2,
      fontSize: 68,
    );

    return HeroIntroSlide(
      imageAsset: 'assets/branding/onboarding_hero_1.2.webp',
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
      primaryCtaLabel: welcomeCtaLabel(),
      onPrimaryCta: onContinue,
      onLogIn: onLogIn,
      overlayColor: context.palette.abyss,
      titleTextStyle: titleStyle,
      subheadTextStyle: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: Colors.white.withValues(alpha: 0.9),
      ),
      // Hand-designed blue-camo backdrop, provided as an asset — richer than
      // the procedural [CamoBackground] painter (kept in the kit for future
      // apps that don't ship one).
      background: Image.asset(
        'assets/branding/camo_background.webp',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
      // The (i) says what analytics is for; the button turns it on.
      termsRich: AnalyticsSmallPrint(
        privacyPolicy: Uri.parse('https://deepblue.org.uk/privacy-policy'),
        color: context.palette.muted,
        child: Text.rich(
          TextSpan(
            text: 'By continuing you agree to the ',
            style: text.bodySmall?.copyWith(color: context.palette.muted),
            children: [
              TextSpan(
                text: 'Privacy Policy',
                style: text.bodySmall?.copyWith(
                  color: context.palette.arcticSoft,
                  decoration: TextDecoration.underline,
                  decorationColor: context.palette.arcticSoft,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                        Uri.parse('https://deepblue.org.uk/privacy-policy'),
                        mode: LaunchMode.externalApplication,
                      ),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Terms of Use',
                style: text.bodySmall?.copyWith(
                  color: context.palette.arcticSoft,
                  decoration: TextDecoration.underline,
                  decorationColor: context.palette.arcticSoft,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                        Uri.parse('https://deepblue.org.uk/terms-of-use'),
                        mode: LaunchMode.externalApplication,
                      ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

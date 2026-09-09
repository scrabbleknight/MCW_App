import 'package:flutter/material.dart';

import 'primary_cta.dart';

/// Full-bleed onboarding welcome screen: a themed backdrop, a hero photo
/// composited over it, a painted-style title behind the subject, and stat +
/// primary CTA at the bottom.
///
/// All copy, images, and colours are passed in — no app-specific strings —
/// so this same widget carries every product's welcome page.
///
/// Z-order (bottom → top):
///   1. [background] widget, or a solid [overlayColor] fill.
///   2. Title + subhead block (top strip).
///   3. Hero photo — optionally composited with [imageBlendMode] so an
///      opaque-black background drops out over the backdrop, letting the
///      subject sit *in front of* the title.
///   4. Dark gradient for bottom-content legibility.
///   5. Tagline + stat + log-in + CTA + terms (bottom strip).
class HeroIntroSlide extends StatelessWidget {
  const HeroIntroSlide({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.subhead,
    required this.tagline,
    required this.statHeadline,
    required this.statCaption,
    required this.primaryCtaLabel,
    required this.onPrimaryCta,
    this.onLogIn,
    this.termsRich,
    this.titleTextStyle,
    this.subheadTextStyle,
    this.overlayColor,
    this.background,
    this.imageBlendMode,
    this.imageHeightFactor = 0.86,
    this.imageVerticalOffset = 0,
    this.imageHorizontalOffset = 0,
    this.dropBlackBackground = true,
  });

  final String imageAsset;
  final String title;
  final String subhead;
  final String tagline;
  final String statHeadline;
  final String statCaption;
  final String primaryCtaLabel;
  final VoidCallback onPrimaryCta;
  final VoidCallback? onLogIn;
  final Widget? termsRich;
  final TextStyle? titleTextStyle;
  final TextStyle? subheadTextStyle;
  final Color? overlayColor;

  /// Painted backdrop that fills the whole screen. Falls back to a solid
  /// [overlayColor] fill when null.
  final Widget? background;

  /// Legacy hook — no longer used since the image is turned into a true
  /// cutout via a colour-matrix filter (see [dropBlackBackground]). Kept for
  /// API compatibility with the first iteration of the kit.
  final BlendMode? imageBlendMode;

  /// When true (default), pixels close to pure black in the hero image are
  /// mapped to alpha 0 via a colour matrix — turning a photo shot on a solid
  /// black backdrop into a true cutout at runtime so it composites cleanly
  /// over the [background] and sits *in front of* the title text.
  final bool dropBlackBackground;

  /// Fraction of the screen height the hero photo occupies (anchored to the
  /// bottom, so the subject's head sits below the top edge).
  final double imageHeightFactor;

  /// Extra vertical shift applied to the hero photo, in logical pixels.
  /// Positive = down (some of the subject clips off the bottom edge),
  /// negative = up. Use to nudge composition without resizing the photo.
  final double imageVerticalOffset;

  /// Extra horizontal shift, in logical pixels. Positive = right, negative
  /// = left. Same purpose as [imageVerticalOffset] on the other axis.
  final double imageHorizontalOffset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final darkGround = overlayColor ?? scheme.surface;

    final resolvedTitleStyle = titleTextStyle ??
        text.displayLarge?.copyWith(
          fontWeight: FontWeight.w900,
          height: 0.9,
          letterSpacing: 1.5,
          color: scheme.onSurface,
        );

    final resolvedSubheadStyle = subheadTextStyle ??
        text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: scheme.onSurface,
        );

    final heroImage = _HeroImage(
      assetPath: imageAsset,
      fallbackColor: darkGround,
      heightFactor: imageHeightFactor,
      verticalOffset: imageVerticalOffset,
      horizontalOffset: imageHorizontalOffset,
      dropBlackBackground: dropBlackBackground,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1 — Backdrop.
        Positioned.fill(
          child: background ?? ColoredBox(color: darkGround),
        ),
        // 2 — Title block, behind the subject.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FittedTitle(text: title, style: resolvedTitleStyle),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      subhead.toUpperCase(),
                      textAlign: TextAlign.right,
                      style: resolvedSubheadStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 3 — Hero photo on top of the title.
        Positioned.fill(child: heroImage),
        // 4 — Bottom gradient for legibility of the CTA block.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 380,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    darkGround.withValues(alpha: 0.55),
                    darkGround.withValues(alpha: 0.95),
                    darkGround,
                  ],
                  stops: const [0.0, 0.35, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 5 — Bottom content, above everything.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tagline,
                    textAlign: TextAlign.center,
                    style: text.titleSmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statHeadline,
                    textAlign: TextAlign.center,
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statCaption,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (onLogIn != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already got an account? ',
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: onLogIn,
                              child: Text(
                                'Log in',
                                style: text.bodyMedium?.copyWith(
                                  color: scheme.secondary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: scheme.secondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  PrimaryCta(label: primaryCtaLabel, onPressed: onPrimaryCta),
                  if (termsRich != null) ...[
                    const SizedBox(height: 12),
                    termsRich!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders a multi-line title where each line scales down to fit the available
/// width — so the display face never wraps mid-word on narrow screens.
class _FittedTitle extends StatelessWidget {
  const _FittedTitle({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(line, style: style, maxLines: 1, softWrap: false),
          ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.assetPath,
    required this.fallbackColor,
    this.heightFactor = 0.86,
    this.verticalOffset = 0,
    this.horizontalOffset = 0,
    this.dropBlackBackground = true,
  });

  final String assetPath;
  final Color fallbackColor;
  final double heightFactor;
  final double verticalOffset;
  final double horizontalOffset;
  final bool dropBlackBackground;

  // Colour matrix that leaves RGB unchanged and rebuilds the alpha channel
  // from the sum of RGB. Tuned as a *soft* ramp (fully transparent at pure
  // black, fully opaque by mid-grey) rather than a hard threshold, so the
  // anti-aliased edges of hair strands and shadows survive intact instead
  // of being shredded into a jagged silhouette. A soft ramp leaves a slight
  // dark halo where the original photo's background was — bake a real alpha
  // channel into the asset if you need it perfectly clean.
  static const List<double> _blackToAlpha = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    5, 5, 5, 0, -50,
  ];

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stack) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                fallbackColor,
                Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.35),
                  fallbackColor,
                ),
              ],
            ),
          ),
        );
      },
    );

    final positioned = Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: heightFactor.clamp(0.4, 1.0),
        widthFactor: 1,
        child: image,
      ),
    );

    final composited = !dropBlackBackground
        ? positioned
        : ColorFiltered(
            colorFilter: const ColorFilter.matrix(_blackToAlpha),
            child: positioned,
          );

    if (verticalOffset == 0 && horizontalOffset == 0) return composited;
    return Transform.translate(
      offset: Offset(horizontalOffset, verticalOffset),
      child: composited,
    );
  }
}

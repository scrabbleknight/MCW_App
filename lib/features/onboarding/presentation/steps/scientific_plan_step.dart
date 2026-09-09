import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';

/// Final onboarding step — a marketing beat that reveals the chosen trainer
/// as the user's coach and pushes into the app with START NOW.
class ScientificPlanStep extends StatelessWidget {
  const ScientificPlanStep({
    super.key,
    required this.trainer,
    required this.onStart,
  });

  final Trainer trainer;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero takes the top ~48% of the available step body.
        Expanded(flex: 48, child: _HeroConversation(trainer: trainer)),
        // Marketing block — tagline + trust badge + 21-days line — sits
        // over a faded blue-camo background.
        Expanded(flex: 52, child: _MarketingPanel(primary: scheme.primary)),
        PrimaryCta(
          label: 'START NOW',
          trailingIcon: null,
          onPressed: onStart,
        ),
      ],
    );
  }
}

class _MarketingPanel extends StatelessWidget {
  const _MarketingPanel({required this.primary});
  final Color primary;

  static const _camoAsset = 'assets/branding/blue_camo_background_2.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Stack(
      children: [
        // Faded camo background: opaque in the middle, transparent at the
        // top and bottom so it blends into the page ink.
        Positioned.fill(
          child: IgnorePointer(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.22, 0.78, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: 0.55,
                child: Image.asset(
                  _camoAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Tagline(),
              _TrustBadge(primary: primary),
              Text(
                'Stick To 21 Days, Witness Your Transformation!',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroConversation extends StatelessWidget {
  const _HeroConversation({required this.trainer});
  final Trainer trainer;

  static const _companionAsset = 'assets/branding/girl_on_right_cutout.png';
  static const _companionPortrait = 'assets/branding/other_girl_portrait.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    // Hero fills the vertical space the parent Expanded hands us — no
    // fixed height, so the panel below never gets pushed off-screen.
    return LayoutBuilder(builder: (context, constraints) {
      final heroHeight = constraints.maxHeight;
      return SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
          // Chosen trainer — left half of the frame, image keeps its aspect
          // ratio and anchors to the inner (right) edge of its half so the
          // arm nearest the middle isn't clipped.
          Positioned(
            left: 0,
            width: size.width * 0.55,
            top: 0,
            bottom: 0,
            child: Image.asset(
              trainer.cutoutAsset,
              fit: BoxFit.fitHeight,
              alignment: Alignment.centerRight,
              filterQuality: FilterQuality.medium,
            ),
          ),
          // Second companion — mirrors the trainer, anchored to its inner
          // (left) edge.
          Positioned(
            right: 0,
            width: size.width * 0.55,
            top: 0,
            bottom: 0,
            child: Image.asset(
              _companionAsset,
              fit: BoxFit.fitHeight,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.medium,
            ),
          ),
          // Complaint bubble — from the companion. Portrait sits to its
          // right so the tail reads as coming from her.
          Positioned(
            left: 8,
            right: 6,
            top: heroHeight * 0.38,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _ChatBubble(
                    text:
                        'I hate boring repetitive workouts — always quit '
                        "cause they're boring and no positive feedback.",
                    background:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                    textColor: scheme.onSurface,
                    textStyle: text.bodyMedium,
                    tail: _BubbleTail.right,
                  ),
                ),
                const SizedBox(width: 8),
                _AvatarChip(
                  imageAsset: _companionPortrait,
                  ringColor: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
          // Trainer's reply — portrait on the left, blue bubble to its right.
          Positioned(
            left: 6,
            right: 8,
            bottom: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AvatarChip(
                  imageAsset: trainer.avatarAsset,
                  ringColor: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChatBubble(
                    text:
                        "That's why you're here for Military Calisthenics!",
                    background: scheme.primary,
                    textColor: Colors.white,
                    textStyle: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    tail: _BubbleTail.left,
                    borderColor: scheme.primary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      );
    });
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.imageAsset, required this.ringColor});
  final String imageAsset;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: ringColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        imageAsset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

enum _BubbleTail { left, right }

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.background,
    required this.textColor,
    required this.textStyle,
    required this.tail,
    this.borderColor,
  });

  final String text;
  final Color background;
  final Color textColor;
  final TextStyle? textStyle;
  final _BubbleTail tail;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    // The "tail corner" — nearest to the speaker's avatar — is small, the
    // other three are large, so the bubble reads as pointing at the avatar.
    final tailLeft = tail == _BubbleTail.left;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(tailLeft ? 4 : 18),
          bottomRight: Radius.circular(tailLeft ? 18 : 4),
        ),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        text,
        style: textStyle?.copyWith(color: textColor),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final big = text.displaySmall?.copyWith(
      fontWeight: FontWeight.w900,
      height: 1.05,
      letterSpacing: 0.6,
    );
    return Column(
      children: [
        Text(
          'SCIENTIFIC PLAN',
          textAlign: TextAlign.center,
          style: big?.copyWith(color: scheme.onSurface.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 6),
        Text(
          'RELAXED VIBE',
          textAlign: TextAlign.center,
          style: big?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 6),
        Text(
          'ALL FOR YOUR GOALS!!',
          textAlign: TextAlign.center,
          style: big?.copyWith(color: scheme.onSurface),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.primary});
  final Color primary;

  static const _laurelGold = Color(0xFFC9A24B);
  static const _leftAsset = 'assets/branding/gold_greek_leaves_left.png';
  static const _rightAsset = 'assets/branding/gold_greek_leaves_right.png';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Both branches rendered at the same on-screen size regardless of
        // source-file dimensions, using BoxFit.contain to preserve aspect.
        const SizedBox(
          width: 64,
          height: 64,
          child: Image(
            image: AssetImage(_leftAsset),
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 0),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trusted by',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '100K+ users',
              style: text.headlineSmall?.copyWith(
                color: _laurelGold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(Icons.star_rounded,
                      color: _laurelGold, size: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        const SizedBox(
          width: 44,
          height: 74,
          child: Image(
            image: AssetImage(_rightAsset),
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

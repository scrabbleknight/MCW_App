import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Final onboarding step — a hard paywall. Presents two plans (weekly and
/// annual, with a free-trial CTA) and gates the app until the user picks.
/// No sticky "skip"; the small X in the corner is optional and off by
/// default (parent decides whether to allow dismissal).
class PaywallStep extends StatefulWidget {
  const PaywallStep({
    super.key,
    required this.onPurchase,
    this.onClose,
    this.onRestore,
    this.onDevSkip,
    this.trialDays = 3,
  });

  /// Fires when the user commits to a plan. Returns `true` when the store
  /// transaction succeeded so the paywall can advance; anything else keeps
  /// the paywall on-screen and pops a generic error SnackBar. The parent is
  /// welcome to show its own error UI beforehand — the paywall's fallback
  /// SnackBar only appears if the caller returns false silently.
  final Future<bool> Function(PaywallPlan) onPurchase;

  /// Optional close hook. Provide null to hide the close button entirely
  /// (true hard paywall) or a callback to show it (e.g. debug builds).
  final VoidCallback? onClose;

  /// Optional "Restore Purchases" hook — surface for App Store review.
  /// Returns `true` when the store surfaced an active entitlement (i.e.
  /// the account is already subscribed). The paywall auto-advances in
  /// that case; `false` shows a "nothing to restore" SnackBar instead.
  final Future<bool> Function()? onRestore;

  /// Debug-only bypass: when provided AND the build is in debug mode, a
  /// small "DEV SKIP" pill appears above the CTA and advances the flow as
  /// if a purchase succeeded. Release builds ignore this callback entirely.
  final VoidCallback? onDevSkip;

  final int trialDays;

  @override
  State<PaywallStep> createState() => _PaywallStepState();
}

class _PaywallStepState extends State<PaywallStep> {
  PaywallPlan _selected = PaywallPlan.yearly;
  bool _restoring = false;
  bool _purchasing = false;

  static const _weeklyPriceLabel = '£12.99/wk';
  static const _yearlyPriceLabel = '£79.99/yr';

  /// Yearly plan advertises the free trial; weekly is a no-trial subscribe.
  String get _ctaLabel => switch (_selected) {
        PaywallPlan.yearly =>
          'START ${widget.trialDays} DAY FREE TRIAL 🙌',
        PaywallPlan.weekly => 'GET STARTED',
      };

  Future<void> _startPurchase() async {
    if (_purchasing || _restoring) return;
    setState(() => _purchasing = true);
    bool ok = false;
    try {
      ok = await widget.onPurchase(_selected);
    } catch (error) {
      ok = false;
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Couldn't complete the purchase. Please try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restore() async {
    final r = widget.onRestore;
    if (r == null || _restoring || _purchasing) return;
    setState(() => _restoring = true);
    var restored = false;
    try {
      restored = await r();
    } catch (_) {
      restored = false;
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
    if (!mounted) return;
    if (restored) {
      // Entitlement is now cached on the controller. Fire the primary buy
      // flow — the controller short-circuits to success so the paywall
      // advances without the App Store buy sheet.
      unawaited(_startPurchase());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No previous purchases found on this Apple ID.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compact the vertical rhythm on smaller phones so both plan cards
    // sit above the fold — hero shrinks in `_HeroSplit`, gaps shrink here.
    final screenH = MediaQuery.of(context).size.height;
    final tight = screenH < 760;
    final gapLg = tight ? 12.0 : 20.0;
    final gapSm = tight ? 8.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSplit(onClose: widget.onClose),
                SizedBox(height: gapLg),
                _Header(),
                SizedBox(height: gapLg),
                _PlanCard(
                  label: 'Yearly Plan',
                  price: _yearlyPriceLabel,
                  badge: 'SAVE 88%',
                  plan: PaywallPlan.yearly,
                  selected: _selected == PaywallPlan.yearly,
                  onTap: () => setState(() => _selected = PaywallPlan.yearly),
                ),
                SizedBox(height: gapSm),
                _PlanCard(
                  label: 'Weekly Plan',
                  price: _weeklyPriceLabel,
                  plan: PaywallPlan.weekly,
                  selected: _selected == PaywallPlan.weekly,
                  onTap: () => setState(() => _selected = PaywallPlan.weekly),
                ),
                SizedBox(height: tight ? 12 : 24),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kDebugMode && widget.onDevSkip != null) ...[
                  _DevSkipPill(onTap: widget.onDevSkip!),
                  const SizedBox(height: 8),
                ],
                _PrimaryCta(
                  label: _ctaLabel,
                  onPressed: _purchasing ? null : _startPurchase,
                  isBusy: _purchasing,
                ),
                if (widget.onRestore != null) ...[
                  const SizedBox(height: 10),
                  _RestoreCta(
                    onPressed:
                        _purchasing || _restoring ? null : _restore,
                    isBusy: _restoring,
                  ),
                ],
                const SizedBox(height: 10),
                const _FooterLinks(),
                const SizedBox(height: 10),
                const _AppStoreBadge(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum PaywallPlan { weekly, yearly }

// ============================================================================
// Hero split image
// ============================================================================

class _HeroSplit extends StatelessWidget {
  const _HeroSplit({this.onClose});
  final VoidCallback? onClose;

  static const _beforeAsset = 'assets/branding/before_image.png';
  static const _afterAsset = 'assets/branding/after_image.png';

  @override
  Widget build(BuildContext context) {
    // Scale the before/after hero to the screen so pricing + CTA always
    // stay above the fold. Ratio is tuned against a 6.7"/812pt reference
    // (~34% of available height) and clamped so the hero never dominates
    // small phones or floats away on tablets.
    final screenH = MediaQuery.of(context).size.height;
    final heroHeight = (screenH * 0.24).clamp(160.0, 240.0);
    return SizedBox(
      height: heroHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Image.asset(_beforeAsset, fit: BoxFit.cover),
                ),
                Expanded(
                  child: Image.asset(_afterAsset, fit: BoxFit.cover),
                ),
              ],
            ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: _CornerChip(label: 'Before'),
            ),
            const Positioned(
              right: 10,
              bottom: 10,
              child: _CornerChip(label: 'After'),
            ),
            if (onClose != null)
              Positioned(
                left: 12,
                top: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onClose,
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CornerChip extends StatelessWidget {
  const _CornerChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ============================================================================
// Header
// ============================================================================

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          'Get Your Personalized Military\nCalisthenics Workout Plan!',
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.star_rounded,
                  color: Color(0xFFE7A83A), size: 26),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Plan card
// ============================================================================

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.price,
    required this.plan,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String price;
  final PaywallPlan plan;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final borderColor =
        selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.35);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected
              ? Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.08),
                  scheme.surface,
                )
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: borderColor, width: 1.8),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    price,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: 16,
            top: -12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// Primary CTA + footer bits
// ============================================================================

/// Small orange-tinted pill that only ships in debug builds — lets you skip
/// past the paywall in the simulator without going through the App Store.
/// Guarded by [kDebugMode] at the callsite so this never lands in a release
/// build even if a wiring mistake left [PaywallStep.onDevSkip] set.
class _DevSkipPill extends StatelessWidget {
  const _DevSkipPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: const Color(0xFFE07B39).withValues(alpha: 0.20),
          shape: StadiumBorder(
            side: BorderSide(
              color: const Color(0xFFE07B39).withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                'DEV · SKIP PAYWALL',
                style: TextStyle(
                  color: Color(0xFFE07B39),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.onPressed,
    this.isBusy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
        ),
        child: isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

/// Prominent secondary button — same width as the primary CTA — used to
/// launch the App Store restore flow. Split out of the tiny link row so
/// existing subscribers can find it without hunting.
class _RestoreCta extends StatelessWidget {
  const _RestoreCta({required this.onPressed, this.isBusy = false});
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.35),
            width: 1.4,
          ),
        ),
        child: isBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: scheme.onSurface,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restore_rounded,
                    size: 18,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Restore Purchases',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final linkStyle = text.bodySmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.65),
      fontWeight: FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _linkButton('Terms', linkStyle, () {}),
        const SizedBox(width: 20),
        _linkButton('Privacy', linkStyle, () {}),
      ],
    );
  }

  Widget _linkButton(String label, TextStyle? style, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(label, style: style),
      ),
    );
  }
}

class _AppStoreBadge extends StatelessWidget {
  const _AppStoreBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_rounded,
            color: scheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Secured with Apple Store',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

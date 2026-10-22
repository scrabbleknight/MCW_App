import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:url_launcher/url_launcher.dart';

/// Final onboarding step — a hard paywall. Presents two plans (weekly and
/// annual, with a free-trial CTA) and gates the app until the user picks.
/// No sticky "skip"; the small X in the corner is optional and off by
/// default (parent decides whether to allow dismissal). A friend's referral
/// code swaps Annual's trial for 50% off the first year.
class PaywallStep extends StatefulWidget {
  const PaywallStep({
    super.key,
    required this.onPurchase,
    this.onClose,
    this.onRestore,
    this.weeklyPrice,
    this.yearlyPrice,
    this.yearlyHasTrial = true,
    this.trialDays = 3,
    this.friendCode,
    this.yearlyFriendOffer = false,
    this.yearlyFriendPrice,
    this.friendOfferIneligible = false,
    this.onApplyFriendCode,
    this.onOpenReferrals,
  });

  /// Fires when the user commits to a plan, with `friendDiscount` set when
  /// they're buying Annual with a friend's referral discount. Returns `true`
  /// when the store
  /// transaction succeeded so the paywall can advance; anything else keeps
  /// the paywall on-screen and pops a generic error SnackBar. The parent is
  /// welcome to show its own error UI beforehand — the paywall's fallback
  /// SnackBar only appears if the caller returns false silently.
  final Future<bool> Function(PaywallPlan plan, bool friendDiscount) onPurchase;

  /// Optional close hook. Provide null to hide the close button entirely
  /// (true hard paywall) or a callback to show it (e.g. debug builds).
  final VoidCallback? onClose;

  /// Optional "Restore Purchases" hook — surface for App Store review.
  /// Returns `true` when the store surfaced an active entitlement (i.e.
  /// the account is already subscribed). The paywall auto-advances in
  /// that case; `false` shows a "nothing to restore" SnackBar instead.
  final Future<bool> Function()? onRestore;

  /// Store prices for each plan. Until both arrive the paywall shows the UK
  /// prices, so it never mixes a store price with a fallback in another
  /// currency.
  final PlanPrice? weeklyPrice;
  final PlanPrice? yearlyPrice;

  /// False when the store says this user has already had the yearly free
  /// trial, so the paywall stops promising one.
  final bool yearlyHasTrial;

  final int trialDays;

  /// A friend's referral code the server accepted and this user hasn't used
  /// yet.
  final String? friendCode;

  /// Whether the store can sell Annual with the friend discount to this
  /// user, and what it costs where the store says (Play only; StoreKit shows
  /// Apple's price on its sheet).
  final bool yearlyFriendOffer;
  final String? yearlyFriendPrice;

  /// iOS: the discount exists but Apple won't give it to this user because
  /// they've subscribed or had a trial before.
  final bool friendOfferIneligible;

  /// Checks a typed friend's code. Returns an error message to show under
  /// the field, or null once the code is accepted. Null hides the link.
  final Future<String?> Function(String code)? onApplyFriendCode;

  /// Opens the user's own referral page. Null hides the invite card.
  final VoidCallback? onOpenReferrals;

  @override
  State<PaywallStep> createState() => _PaywallStepState();
}

class _PaywallStepState extends State<PaywallStep> {
  PaywallPlan _selected = PaywallPlan.yearly;
  bool _restoring = false;
  bool _purchasing = false;

  /// The user turned an accepted friend's code off for this visit.
  bool _friendDiscountOff = false;

  // Shown until the store answers, or when it can't be reached. These match
  // the UK prices in App Store Connect and Play Console.
  static const PlanPrice _fallbackWeekly = (formatted: '£6.99', amount: 6.99);
  static const PlanPrice _fallbackYearly = (formatted: '£59.99', amount: 59.99);

  bool get _hasStorePrices =>
      widget.weeklyPrice != null && widget.yearlyPrice != null;
  PlanPrice get _weekly =>
      _hasStorePrices ? widget.weeklyPrice! : _fallbackWeekly;
  PlanPrice get _yearly =>
      _hasStorePrices ? widget.yearlyPrice! : _fallbackYearly;

  String get _yearlyRenewalLabel => '${_yearly.formatted} per year';

  bool get _friendOn => widget.friendCode != null && !_friendDiscountOff;

  /// Annual is sold with the friend discount: a code is on and the store
  /// has the offer for this user.
  bool get _yearlyDiscount => _friendOn && widget.yearlyFriendOffer;

  bool get _selectedDiscount =>
      _yearlyDiscount && _selected == PaywallPlan.yearly;

  /// The friend discount replaces Annual's trial.
  bool get _showTrial => widget.yearlyHasTrial && !_yearlyDiscount;

  /// The store's discounted price where it gives one (Play), otherwise the
  /// discount itself: StoreKit shows Apple's exact price on its sheet.
  String get _yearlyDiscountLine => widget.yearlyFriendPrice == null
      ? '50% off your first year'
      : '${widget.yearlyFriendPrice} for your first year';

  /// How much cheaper a year on the annual plan is than 52 weeks of the
  /// weekly plan, rounded down so the badge never overstates it.
  String? get _savingsBadge {
    final weeklyForAYear = _weekly.amount * 52;
    if (weeklyForAYear <= 0) return null;
    final percent = ((1 - _yearly.amount / weeklyForAYear) * 100).floor();
    return percent > 0 ? 'SAVE $percent%' : null;
  }

  /// Yearly plan advertises the free trial when the user can get one;
  /// otherwise both plans are a straight subscribe.
  String get _ctaLabel => _selectedDiscount
      ? 'CLAIM 50% OFF 🙌'
      : _selected == PaywallPlan.yearly && _showTrial
      ? 'START ${widget.trialDays} DAY FREE TRIAL 🙌'
      : 'GET STARTED';

  Future<void> _startPurchase() async {
    if (_purchasing || _restoring) return;
    setState(() => _purchasing = true);
    bool ok = false;
    try {
      ok = await widget.onPurchase(_selected, _selectedDiscount);
    } catch (error) {
      ok = false;
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't complete the purchase. Please try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _enterFriendCode() async {
    final apply = widget.onApplyFriendCode;
    if (apply == null || _purchasing) return;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FriendCodeSheet(onApply: apply),
    );
    if (applied != true || !mounted) return;
    // The friend discount is on Annual, so show it there.
    setState(() {
      _friendDiscountOff = false;
      _selected = PaywallPlan.yearly;
    });
    // Let the parent rebuild with the store's answer for this code first.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.yearlyFriendOffer
              ? 'Code applied: 50% off your first year of Annual.'
              : widget.friendOfferIneligible
              ? 'Code saved, but the discount is only for new subscribers.'
              : "Code saved, but the discount isn't available from the "
                    '${StorePlatform.storeName} yet. Please try again later.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        SnackBar(
          content: Text(
            'No previous purchases found on this '
            '${StorePlatform.billingAccountName}.',
          ),
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroSplit(onClose: widget.onClose),
          SizedBox(height: gapSm),
          _Header(),
          if (widget.onOpenReferrals != null) ...[
            SizedBox(height: gapSm),
            _ReferralPromo(
              onOpen: widget.onOpenReferrals!,
              onEnterCode:
                  widget.friendCode == null && widget.onApplyFriendCode != null
                  ? _enterFriendCode
                  : null,
            ),
          ],
          SizedBox(height: gapLg),
          _PlanCard(
            label: 'Yearly Plan',
            price: '${_yearly.formatted}/yr',
            subtitle: _yearlyDiscount
                ? '$_yearlyDiscountLine, then $_yearlyRenewalLabel'
                : _showTrial
                ? '${widget.trialDays}-day free trial, then '
                      '$_yearlyRenewalLabel'
                : 'Billed yearly',
            badge: _yearlyDiscount ? '50% OFF' : _savingsBadge,
            plan: PaywallPlan.yearly,
            selected: _selected == PaywallPlan.yearly,
            onTap: () => setState(() => _selected = PaywallPlan.yearly),
          ),
          SizedBox(height: gapSm),
          _PlanCard(
            label: 'Weekly Plan',
            price: '${_weekly.formatted}/wk',
            plan: PaywallPlan.weekly,
            selected: _selected == PaywallPlan.weekly,
            onTap: () => setState(() => _selected = PaywallPlan.weekly),
          ),
          if (widget.friendCode != null)
            _FriendCodeRow(
              code: widget.friendCode!,
              on: _friendOn,
              available: widget.yearlyFriendOffer,
              ineligible: widget.friendOfferIneligible,
              onToggle: () =>
                  setState(() => _friendDiscountOff = !_friendDiscountOff),
            )
          else if (widget.onApplyFriendCode != null &&
              widget.onOpenReferrals == null)
            Center(
              child: TextButton(
                onPressed: _purchasing ? null : _enterFriendCode,
                child: const Text("Got a friend's code? Get 50% off"),
              ),
            ),
          const SizedBox(height: 14),
          const _FooterLinks(),
          const SizedBox(height: 10),
          _TrialDisclosure(
            trialDays: _showTrial ? widget.trialDays : null,
            yearlyRenewalLabel: _yearlyRenewalLabel,
            friendDiscountLine: _yearlyDiscount ? _yearlyDiscountLine : null,
          ),
          const SizedBox(height: 10),
          const _AppStoreBadge(),
          const SizedBox(height: 24),
          _PrimaryCta(
            label: _ctaLabel,
            onPressed: _purchasing ? null : _startPurchase,
            isBusy: _purchasing,
          ),
          if (widget.onRestore != null) ...[
            const SizedBox(height: 10),
            _RestoreCta(
              onPressed: _purchasing || _restoring ? null : _restore,
              isBusy: _restoring,
            ),
          ],
          SizedBox(height: tight ? 12 : 24),
        ],
      ),
    );
  }
}

enum PaywallPlan { weekly, yearly }

/// A plan's price: [formatted] for display (currency symbol included) and
/// [amount] in that currency for working out savings.
typedef PlanPrice = ({String formatted, double amount});

// ============================================================================
// Hero split image
// ============================================================================

class _HeroSplit extends StatelessWidget {
  const _HeroSplit({this.onClose});
  final VoidCallback? onClose;

  static const _beforeAsset = 'assets/branding/before_image.webp';
  static const _afterAsset = 'assets/branding/after_image.webp';

  @override
  Widget build(BuildContext context) {
    // Scale the before/after hero to the screen so pricing + CTA always
    // stay above the fold. Ratio is tuned against a 6.7"/812pt reference
    // (~34% of available height) and clamped so the hero never dominates
    // small phones or floats away on tablets.
    final screenH = MediaQuery.of(context).size.height;
    final heroHeight = (screenH * 0.17).clamp(120.0, 170.0);
    return SizedBox(
      height: heroHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(child: Image.asset(_beforeAsset, fit: BoxFit.cover)),
                Expanded(child: Image.asset(_afterAsset, fit: BoxFit.cover)),
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
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
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
              child: Icon(
                Icons.star_rounded,
                color: Color(0xFFE7A83A),
                size: 26,
              ),
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
    this.subtitle,
    this.badge,
  });

  final String label;
  final String price;
  final PaywallPlan plan;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final borderColor = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.35);
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.70),
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
    final hasHandsEmoji = label.endsWith(' 🙌');
    final textLabel = hasHandsEmoji
        ? label.substring(0, label.length - ' 🙌'.length)
        : label;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        child: isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    textLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      fontSize: 16,
                    ),
                  ),
                  if (hasHandsEmoji) ...[
                    const SizedBox(width: 6),
                    Transform.translate(
                      offset: const Offset(0, -2),
                      child: const Text(
                        '🙌',
                        style: TextStyle(fontSize: 18, height: 1),
                      ),
                    ),
                  ],
                ],
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
        _linkButton('Terms', linkStyle, () {
          launchUrl(
            Uri.parse('https://deepblue.org.uk/terms-of-use'),
            mode: LaunchMode.externalApplication,
          );
        }),
        const SizedBox(width: 20),
        _linkButton('Privacy', linkStyle, () {
          launchUrl(
            Uri.parse('https://deepblue.org.uk/privacy-policy'),
            mode: LaunchMode.externalApplication,
          );
        }),
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

class _TrialDisclosure extends StatelessWidget {
  const _TrialDisclosure({
    required this.trialDays,
    required this.yearlyRenewalLabel,
    this.friendDiscountLine,
  });

  /// Null when the user can't get the free trial.
  final int? trialDays;
  final String yearlyRenewalLabel;

  /// Annual's referral discount ("50% off your first year"), when a
  /// friend's code is on. It replaces the trial.
  final String? friendDiscountLine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final primaryStyle = text.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.78),
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final secondaryStyle = text.bodySmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.62),
      fontWeight: FontWeight.w500,
      height: 1.25,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Text(
            friendDiscountLine != null
                ? 'Annual plan: $friendDiscountLine, then '
                      '$yearlyRenewalLabel. Subscription auto-renews until '
                      'cancelled.'
                : trialDays != null
                ? 'Annual plan includes a $trialDays-day free trial, then '
                      '$yearlyRenewalLabel. Subscription auto-renews until '
                      'cancelled.'
                : 'Annual plan renews at $yearlyRenewalLabel. Subscription '
                      'auto-renews until cancelled.',
            textAlign: TextAlign.center,
            style: primaryStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Payment is charged to your ${StorePlatform.billingAccountName} '
            'at confirmation of purchase. Manage or cancel any time in '
            '${StorePlatform.manageSubscriptionsLocation}.',
            textAlign: TextAlign.center,
            style: secondaryStyle,
          ),
        ],
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
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_rounded, color: scheme.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            'Secured with ${StorePlatform.storeName}',
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

// ============================================================================
// Referrals
// ============================================================================

/// The referral programme, near the top where everyone sees it: invite
/// friends to earn up to free for life (opens the referral page), or enter
/// a friend's code for 50% off.
class _ReferralPromo extends StatelessWidget {
  const _ReferralPromo({required this.onOpen, required this.onEnterCode});

  final VoidCallback onOpen;

  /// Null once a friend's code has been applied.
  final VoidCallback? onEnterCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.26),
              scheme.primary.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: scheme.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(18),
                bottom: Radius.circular(onEnterCode == null ? 18 : 0),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          color: scheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Invite friends, get it free',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        _RewardChip(friends: 1, reward: '50% off\n1 year'),
                        SizedBox(width: 8),
                        _RewardChip(friends: 2, reward: '1 year\nfree'),
                        SizedBox(width: 8),
                        _RewardChip(friends: 3, reward: 'Free\nfor life'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onEnterCode != null) ...[
              Divider(height: 1, color: scheme.primary.withValues(alpha: 0.4)),
              InkWell(
                onTap: onEnterCode,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "Got a friend's code? Get 50% off",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.friends, required this.reward});
  final int friends;
  final String reward;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              friends == 1 ? '1 friend' : '$friends friends',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              reward,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The applied friend's code, with a way to turn it off (to take the free
/// trial instead) and back on.
class _FriendCodeRow extends StatelessWidget {
  const _FriendCodeRow({
    required this.code,
    required this.on,
    required this.available,
    required this.ineligible,
    required this.onToggle,
  });

  final String code;
  final bool on;
  final bool available;
  final bool ineligible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = !available && ineligible
        ? 'Code $code saved, but the discount is for new subscribers and '
              'this ${StorePlatform.billingAccountName} has subscribed before.'
        : !available
        ? "Code $code saved. The discount isn't available from the "
              '${StorePlatform.storeName} yet.'
        : on
        ? "Friend's code $code applied: 50% off your first year of Annual."
        : "Friend's code $code is turned off.";
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: on && available ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                message,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ),
          if (available)
            TextButton(
              onPressed: onToggle,
              child: Text(on ? 'Turn off' : 'Use it'),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet for typing in a friend's referral code. Pops with true once
/// [onApply] reports the code accepted.
class _FriendCodeSheet extends StatefulWidget {
  const _FriendCodeSheet({required this.onApply});

  final Future<String?> Function(String code) onApply;

  @override
  State<_FriendCodeSheet> createState() => _FriendCodeSheetState();
}

class _FriendCodeSheetState extends State<_FriendCodeSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onApply(code);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Got a friend's code?",
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter it to get 50% off your first year of Annual.',
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
              LengthLimitingTextInputFormatter(9),
            ],
            onSubmitted: (_) => _apply(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              errorText: _error,
              errorMaxLines: 3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _apply,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text(
                      'APPLY CODE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

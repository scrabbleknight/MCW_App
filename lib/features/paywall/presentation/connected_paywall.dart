import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/funnel/recovery_offer.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/recovery_offer_screen.dart';
import 'package:military_calisthenics_women/features/referrals/application/referral_controller.dart';
import 'package:military_calisthenics_women/features/referrals/presentation/referral_screen.dart';
import 'package:provider/provider.dart';

/// [PaywallStep] wired to the store and the referral programme. Used at the
/// end of onboarding and by the subscription gate.
class ConnectedPaywall extends StatefulWidget {
  const ConnectedPaywall({super.key, this.onPurchased, this.placement});

  /// Called after a successful purchase or restore, with the plan bought.
  final void Function(PaywallPlan plan)? onPurchased;

  /// Funnel analytics placement ([PaywallPlacement]). Defaults to
  /// onboarding if it finished this visit, else gate.
  final String? placement;

  /// Funnel analytics id for this paywall design.
  static const funnelId = 'paywall_v1';

  @override
  State<ConnectedPaywall> createState() => _ConnectedPaywallState();
}

class _ConnectedPaywallState extends State<ConnectedPaywall>
    with WidgetsBindingObserver {
  late final String _placement;

  @override
  void initState() {
    super.initState();
    final funnel = context.read<FunnelTracker>();
    _placement = widget.placement ?? funnel.gatePlacement;
    funnel.paywallView(
      paywallId: ConnectedPaywall.funnelId,
      placement: _placement,
    );
    WidgetsBinding.instance.addObserver(this);
    // Picks up a friend's code entered on an earlier visit. Only for people
    // with an account already; nobody is signed in just to look.
    context.read<ReferralController>().refresh().catchError((Object error) {
      debugPrint('Paywall: referral status unavailable — $error');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Android back on the paywall leaves the app (it's the root screen).
  /// Only logged; the system still handles it. Not called while a screen
  /// pushed on top (referrals, log in) takes the back press. While the exit
  /// recovery offer can be shown, back opens it instead (the PopScope in
  /// [build]) and isn't a dismiss.
  @override
  Future<bool> didPopRoute() async {
    if (_canOfferRecovery) return false;
    context.read<FunnelTracker>().paywallDismiss(
      paywallId: ConnectedPaywall.funnelId,
      placement: _placement,
      method: PaywallDismissMethod.systemBack,
    );
    return false;
  }

  /// The recovery offer is open, so a second trigger doesn't open another.
  bool _recoveryOpen = false;

  /// Whether leaving now would show the exit recovery offer: this user can
  /// get it and hasn't seen it on this install.
  bool get _canOfferRecovery =>
      context.read<PurchaseController>().recoveryOffer != null &&
      !context.read<RecoveryOfferController>().alreadyShown;

  /// Someone tried to leave without buying ([method] is a
  /// [PaywallDismissMethod]). Shows the recovery offer when they can get it
  /// and returns whether it was shown. After declining it, Android back and
  /// the close button leave the app as back always has; iOS apps can't
  /// close themselves, so iOS (and a closed store sheet) returns to the
  /// paywall.
  Future<bool> _exitAttempt(String method) async {
    final funnel = context.read<FunnelTracker>();
    final terms = context.read<PurchaseController>().recoveryOffer;
    final eligible = !_recoveryOpen && _canOfferRecovery && terms != null;
    funnel.paywallExitAttempt(
      paywallId: ConnectedPaywall.funnelId,
      placement: _placement,
      method: method,
      offerEligible: eligible,
    );
    if (!eligible) return false;
    _recoveryOpen = true;
    await context.read<RecoveryOfferController>().markShown(
      terms,
      trigger: method,
      placement: _placement,
    );
    // Hides the close button and hands Android back to the system again.
    if (mounted) setState(() {});
    if (!mounted) return true;
    final leaving =
        StorePlatform.isAndroid &&
        method != PaywallDismissMethod.storeSheetCancel;
    final result = await showRecoveryOffer(
      context,
      terms: terms,
      leaving: leaving,
      placement: _placement,
    );
    _recoveryOpen = false;
    if (!mounted) return true;
    if (result == RecoveryResult.purchased) {
      widget.onPurchased?.call(PaywallPlan.monthly);
    } else if (leaving) {
      funnel.paywallDismiss(
        paywallId: ConnectedPaywall.funnelId,
        placement: _placement,
        method: method,
      );
      await SystemNavigator.pop();
    }
    return true;
  }

  Future<String?> _applyFriendCode(String code) async {
    try {
      await context.read<ReferralController>().applyCode(code);
      return null;
    } on ReferralException catch (error) {
      return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchases = context.read<PurchaseController>();
    // Rebuild when the store's prices, trial eligibility and friend offer
    // arrive, but not on every purchase state change.
    final (
      monthlyPrice,
      yearlyPrice,
      yearlyHasTrial,
      yearlyFriendOffer,
      yearlyFriendPrice,
      friendIneligible,
    ) = context.select(
      (PurchaseController p) => (
        p.priceFor(PaywallPlan.monthly),
        p.priceFor(PaywallPlan.yearly),
        p.hasFreeTrial(PaywallPlan.yearly),
        p.hasFriendOffer(PaywallPlan.yearly),
        p.friendOfferPrice(PaywallPlan.yearly),
        p.friendOfferIneligible,
      ),
    );
    final friendCode = context.select(
      (ReferralController r) =>
          r.hasFriendDiscount ? r.status!.friendDiscount!.code : null,
    );
    // Rebuild when the store's recovery offer arrives (or stops applying).
    final canOffer =
        context.select((PurchaseController p) => p.recoveryOffer != null) &&
        !Provider.of<RecoveryOfferController>(
          context,
          listen: false,
        ).alreadyShown;
    return PopScope(
      // While the recovery offer can be shown, Android back opens it rather
      // than leaving the app.
      canPop: !canOffer,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitAttempt(PaywallDismissMethod.systemBack);
      },
      child: PaywallStep(
        onClose: canOffer
            ? () => _exitAttempt(PaywallDismissMethod.close)
            : null,
        monthlyPrice: monthlyPrice,
        yearlyPrice: yearlyPrice,
        yearlyHasTrial: yearlyHasTrial,
        friendCode: friendCode,
        yearlyFriendOffer: yearlyFriendOffer,
        yearlyFriendPrice: yearlyFriendPrice,
        friendOfferIneligible: friendIneligible,
        onApplyFriendCode: _applyFriendCode,
        onOpenReferrals: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ReferralScreen())),
        onPurchase: (plan, friendDiscount) async {
          final outcome = await purchases.purchase(
            plan,
            friendDiscount: friendDiscount,
            placement: _placement,
          );
          if (outcome == PurchaseOutcome.cancelled) {
            // Closing the store's sheet: the recovery offer, once. Shown means
            // handled, so the paywall's "couldn't complete" message stays away.
            return _exitAttempt(PaywallDismissMethod.storeSheetCancel);
          }
          if (outcome != PurchaseOutcome.success) return false;
          widget.onPurchased?.call(plan);
          return true;
        },
        onRestore: purchases.restore,
      ),
    );
  }
}

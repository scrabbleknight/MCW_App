import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';
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
  /// pushed on top (referrals, log in) takes the back press.
  @override
  Future<bool> didPopRoute() async {
    context.read<FunnelTracker>().paywallDismiss(
      paywallId: ConnectedPaywall.funnelId,
      placement: _placement,
      method: PaywallDismissMethod.systemBack,
    );
    return false;
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
    return PaywallStep(
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
        if (outcome != PurchaseOutcome.success) return false;
        widget.onPurchased?.call(plan);
        return true;
      },
      onRestore: purchases.restore,
    );
  }
}

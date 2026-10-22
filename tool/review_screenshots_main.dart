// Entry point for App Store review screenshots and layout checks. Shows the
// real paywall / referral screens with stand-in store and referral data, so
// no store, Firebase or onboarding is needed.
//
//   flutter run -t tool/review_screenshots_main.dart --dart-define=SCREEN=paywall
//   SCREEN = paywall | friend | referral
import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/core/theme/tactical_theme.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/connected_paywall.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';
import 'package:military_calisthenics_women/features/referrals/application/referral_controller.dart';
import 'package:military_calisthenics_women/features/referrals/presentation/referral_screen.dart';
import 'package:provider/provider.dart';

const _screen = String.fromEnvironment('SCREEN', defaultValue: 'paywall');

class _Referrals extends ReferralController {
  _Referrals(this._fake);
  final ReferralStatus? _fake;
  @override
  ReferralStatus? get status => _fake;
  @override
  bool get hasFriendDiscount =>
      _fake?.friendDiscount?.state == FriendDiscountState.available;
  @override
  Future<void> refresh({bool createAccount = false}) async {}
}

class _Purchases extends PurchaseController {
  _Purchases({required this.friendOffers});
  final bool friendOffers;
  @override
  bool hasFriendOffer(PaywallPlan plan) =>
      friendOffers && plan == PaywallPlan.yearly;
  @override
  bool get friendOfferIneligible => false;
}

ReferralStatus _status({
  required int friends,
  required List<String> states,
  Map<String, Object?>? friendDiscount,
}) => ReferralStatus.fromJson({
  'code': 'K7MQ4P',
  'friends': friends,
  'tiers': [
    {'reward': 'half_1y', 'friends': 1, 'state': states[0]},
    {'reward': 'free_1y', 'friends': 2, 'state': states[1]},
    {'reward': 'lifetime', 'friends': 3, 'state': states[2]},
  ],
  'friendDiscount': friendDiscount,
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final (referrals, purchases, home) = switch (_screen) {
    'friend' => (
      _Referrals(
        _status(
          friends: 0,
          states: const ['locked', 'locked', 'locked'],
          friendDiscount: {'code': 'K7MQ4P', 'state': 'available'},
        ),
      ),
      _Purchases(friendOffers: true),
      const _GatePaywall() as Widget,
    ),
    'referral' => (
      _Referrals(
        _status(friends: 3, states: const ['redeemed', 'redeemed', 'earned']),
      ),
      _Purchases(friendOffers: false),
      const ReferralScreen() as Widget,
    ),
    _ => (
      _Referrals(null),
      _Purchases(friendOffers: false),
      const _GatePaywall() as Widget,
    ),
  };
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ReferralController>.value(value: referrals),
        ChangeNotifierProvider<PurchaseController>.value(value: purchases),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: TacticalTheme.light(),
        darkTheme: TacticalTheme.dark(),
        themeMode: ThemeMode.dark,
        home: home,
      ),
    ),
  );
}

/// The paywall as the subscription gate shows it (lib/app/mcw_app.dart).
class _GatePaywall extends StatelessWidget {
  const _GatePaywall();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.abyss,
    body: const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: ConnectedPaywall(),
      ),
    ),
  );
}

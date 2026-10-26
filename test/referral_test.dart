import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';
import 'package:military_calisthenics_women/features/referrals/application/referral_controller.dart';

void main() {
  group('ReferralStatus', () {
    test('parses the referralStatus response', () {
      final status = ReferralStatus.fromJson({
        'code': 'ABC234',
        'friends': 3,
        'tiers': [
          {'reward': 'half_1y', 'friends': 1, 'state': 'redeemed'},
          {
            'reward': 'free_1y',
            'friends': 2,
            'state': 'scheduled',
            'appliesAt': '2027-04-21T06:00:00.000Z',
          },
          {
            'reward': 'lifetime',
            'friends': 3,
            'state': 'codeIssued',
            'code': 'LIFE1',
            'redeemUrl': 'https://apps.apple.com/redeem?code=LIFE1',
          },
          {'reward': 'unknown_future_reward', 'friends': 9, 'state': 'locked'},
        ],
        'friendDiscount': {'code': 'XYZ789', 'state': 'available'},
      });
      expect(status.code, 'ABC234');
      expect(status.friends, 3);
      expect(status.tiers.map((t) => t.reward), ReferralReward.values);
      expect(status.tiers[1].state, RewardState.scheduled);
      expect(status.tiers[1].appliesAt, DateTime.utc(2027, 4, 21, 6));
      expect(status.tiers[2].redeemUrl?.host, 'apps.apple.com');
      expect(status.friendDiscount?.code, 'XYZ789');
      // An issued Lifetime code and an unused friend discount both wait on a
      // purchase.
      expect(status.awaitsPurchase, isTrue);
    });

    test('unknown states read as locked', () {
      expect(RewardState.fromId('something-new'), RewardState.locked);
      expect(RewardState.fromId(null), RewardState.locked);
    });
  });

  group('Paywall referrals', () {
    Widget paywall({
      String? friendCode,
      bool yearlyFriendOffer = false,
      String? yearlyFriendPrice,
      bool friendOfferIneligible = false,
      Future<String?> Function(String)? onApply,
      void Function(PaywallPlan, bool)? onBuy,
    }) => MaterialApp(
      home: Scaffold(
        body: PaywallStep(
          onPurchase: (plan, friendDiscount) async {
            onBuy?.call(plan, friendDiscount);
            return true;
          },
          friendCode: friendCode,
          yearlyFriendOffer: yearlyFriendOffer,
          yearlyFriendPrice: yearlyFriendPrice,
          friendOfferIneligible: friendOfferIneligible,
          onApplyFriendCode: onApply ?? (_) async => null,
          onOpenReferrals: () {},
        ),
      ),
    );

    // App Review 3.1.2(c): what the subscription unlocks, on a small phone
    // (and on iPad, which runs this iPhone-only app at about this size).
    testWidgets('lists what the subscription unlocks on a small screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(paywall());
      expect(tester.takeException(), isNull);
      expect(find.text('Your subscription unlocks'), findsOneWidget);
      for (final f in [
        'Personalized plan',
        'Exercise videos',
        'Custom workouts',
        'Progress tracking',
      ]) {
        expect(find.text(f), findsOneWidget);
      }
    });

    testWidgets('offers Monthly and Yearly at the UK prices until the store '
        'answers', (tester) async {
      await tester.pumpWidget(paywall());
      expect(find.text('Monthly Plan'), findsOneWidget);
      expect(find.text('£14.99/mo'), findsOneWidget);
      expect(find.text('Yearly Plan'), findsOneWidget);
      expect(find.text('£49.99/yr'), findsOneWidget);
      // £49.99 against 12 × £14.99 = £179.88.
      expect(find.text('SAVE 72%'), findsOneWidget);
      expect(find.textContaining('Weekly'), findsNothing);
    });

    testWidgets('shows the invite card with all three rewards', (tester) async {
      await tester.pumpWidget(paywall());
      expect(find.text('Invite friends, get it free'), findsOneWidget);
      expect(find.text('50% off\n1 year'), findsOneWidget);
      expect(find.text('1 year\nfree'), findsOneWidget);
      expect(find.text('Free\nfor life'), findsOneWidget);
      expect(find.text("Got a friend's code? Get 50% off"), findsOneWidget);
    });

    testWidgets('shows the server error under the code field', (tester) async {
      await tester.pumpWidget(
        paywall(onApply: (_) async => "That code doesn't exist."),
      );
      await tester.tap(find.text("Got a friend's code? Get 50% off"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nope12');
      await tester.tap(find.text('APPLY CODE'));
      await tester.pumpAndSettle();
      expect(find.text("That code doesn't exist."), findsOneWidget);
    });

    testWidgets('an applied code makes Annual 50% off the first year', (
      tester,
    ) async {
      PaywallPlan? boughtPlan;
      bool? boughtWithDiscount;
      await tester.pumpWidget(
        paywall(
          friendCode: 'XYZ789',
          yearlyFriendOffer: true,
          onBuy: (plan, discount) {
            boughtPlan = plan;
            boughtWithDiscount = discount;
          },
        ),
      );
      expect(
        find.text('50% off your first year, then £49.99 per year'),
        findsOneWidget,
      );
      expect(find.text('50% OFF'), findsOneWidget);
      expect(find.textContaining('free trial'), findsNothing);
      // Once a code is applied the link to enter one goes away.
      expect(find.text("Got a friend's code? Get 50% off"), findsNothing);

      await tester.scrollUntilVisible(find.text('CLAIM 50% OFF'), 200);
      await tester.tap(find.text('CLAIM 50% OFF'));
      await tester.pumpAndSettle();
      expect(boughtPlan, PaywallPlan.yearly);
      expect(boughtWithDiscount, isTrue);
    });

    testWidgets('Play shows its discounted price', (tester) async {
      await tester.pumpWidget(
        paywall(
          friendCode: 'XYZ789',
          yearlyFriendOffer: true,
          yearlyFriendPrice: '£24.99',
        ),
      );
      expect(
        find.text('£24.99 for your first year, then £49.99 per year'),
        findsOneWidget,
      );
    });

    testWidgets('Monthly never gets the discount', (tester) async {
      bool? boughtWithDiscount;
      await tester.pumpWidget(
        paywall(
          friendCode: 'XYZ789',
          yearlyFriendOffer: true,
          onBuy: (_, discount) => boughtWithDiscount = discount,
        ),
      );
      await tester.tap(find.text('Monthly Plan'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('GET STARTED'), 200);
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();
      expect(boughtWithDiscount, isFalse);
    });

    testWidgets('turning the code off brings the trial back', (tester) async {
      await tester.pumpWidget(
        paywall(friendCode: 'XYZ789', yearlyFriendOffer: true),
      );
      await tester.scrollUntilVisible(find.text('Turn off'), 200);
      await tester.tap(find.text('Turn off'));
      await tester.pump();
      expect(find.text("Friend's code XYZ789 is turned off."), findsOneWidget);
      expect(find.textContaining('3-day free trial'), findsWidgets);
      expect(find.text('Use it'), findsOneWidget);
    });

    testWidgets('explains when Apple won\'t give the discount', (tester) async {
      await tester.pumpWidget(
        paywall(friendCode: 'XYZ789', friendOfferIneligible: true),
      );
      expect(
        find.textContaining('the discount is for new subscribers'),
        findsOneWidget,
      );
      expect(find.text('Turn off'), findsNothing);
      expect(find.textContaining('3-day free trial'), findsWidgets);
    });
  });
}

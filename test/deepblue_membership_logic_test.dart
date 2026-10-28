// GENERATED from ViralEngine/deepblue-kit/dart/test/deepblue_membership_logic_test.dart — edit it there and run `npm run deepblue:sync`.
import 'package:flutter_test/flutter_test.dart';
import 'package:military_calisthenics_women/core/deepblue/deepblue_membership_logic.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 12);

  DeepBlueMembershipSnapshot snap({
    bool active = true,
    Duration endIn = const Duration(days: 20),
    Duration checkedAgo = const Duration(hours: 1),
  }) => DeepBlueMembershipSnapshot(
    active: active,
    status: active ? 'active' : 'canceled',
    plan: 'monthly',
    currentPeriodEnd: now.add(endIn),
    checkedAt: now.subtract(checkedAgo),
  );

  test('an active, recently checked membership grants premium', () {
    expect(snap().grantsAt(now), isTrue);
  });

  test('inactive, none, or past the period end grants nothing', () {
    expect(snap(active: false).grantsAt(now), isFalse);
    expect(DeepBlueMembershipSnapshot.none.grantsAt(now), isFalse);
    expect(snap(endIn: -const Duration(minutes: 1)).grantsAt(now), isFalse);
  });

  test('offline grace: 14 days without reaching the server, then locked', () {
    expect(snap(checkedAgo: const Duration(days: 13)).grantsAt(now), isTrue);
    expect(snap(checkedAgo: const Duration(days: 15)).grantsAt(now), isFalse);
  });

  test('grace never extends past the paid period', () {
    final s = snap(endIn: const Duration(days: 2), checkedAgo: Duration.zero);
    expect(s.grantsAt(now.add(const Duration(days: 3))), isFalse);
  });

  test('a clock moved back before the last check does not unlock', () {
    expect(snap(checkedAgo: -const Duration(days: 1)).grantsAt(now), isFalse);
  });

  test('server response and cache round-trip', () {
    final s = DeepBlueMembershipSnapshot.fromServer({
      'active': true,
      'status': 'active',
      'plan': 'annual',
      'currentPeriodEnd': now.add(const Duration(days: 300)).millisecondsSinceEpoch ~/ 1000,
      'cancelAtPeriodEnd': false,
    }, now: now);
    expect(s.plan, 'annual');
    expect(s.grantsAt(now), isTrue);
    expect(DeepBlueMembershipSnapshot.fromJson(s.toJson()), s);
  });

  test('premium is the app purchase OR the membership, nothing else', () {
    expect(hasPremium(individualAppPurchase: true, deepBlueMembership: false), isTrue);
    expect(hasPremium(individualAppPurchase: false, deepBlueMembership: true), isTrue);
    expect(hasPremium(individualAppPurchase: false, deepBlueMembership: false), isFalse);
  });
}

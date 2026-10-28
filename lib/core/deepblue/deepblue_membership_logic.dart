// GENERATED from ViralEngine/deepblue-kit/dart/deepblue_membership_logic.dart — edit it there and run `npm run deepblue:sync`.
import 'package:flutter/foundation.dart';

/// The DeepBlue All Access membership as the central server last reported it
/// (`deepblueGetMembership`), kept on the device so premium survives a spell
/// offline. Pure: no Firebase, so it's unit-tested on its own.
@immutable
class DeepBlueMembershipSnapshot {
  const DeepBlueMembershipSnapshot({
    required this.active,
    required this.checkedAt,
    this.status = 'none',
    this.plan,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  static const none = DeepBlueMembershipSnapshot(active: false, checkedAt: null);

  /// How long access holds without reaching the server, matching the store
  /// subscriptions' offline grace. Never beyond the paid period's end.
  static const offlineGrace = Duration(days: 14);

  final bool active;
  final String status;
  final String? plan;

  /// End of the paid period (renewal date, or when access stops after a
  /// cancellation).
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  /// When the server said this. Null for [none].
  final DateTime? checkedAt;

  /// Whether premium is unlocked at [now]: the server said active, the paid
  /// period hasn't ended, and the answer isn't older than [offlineGrace].
  bool grantsAt(DateTime now) {
    final end = currentPeriodEnd;
    final checked = checkedAt;
    if (!active || end == null || checked == null) return false;
    if (!now.isBefore(end)) return false;
    if (now.isBefore(checked.subtract(const Duration(minutes: 5)))) {
      return false; // clock moved back past the check: don't trust it
    }
    return now.difference(checked) < offlineGrace;
  }

  /// From the callable's response.
  factory DeepBlueMembershipSnapshot.fromServer(
    Map<Object?, Object?> data, {
    required DateTime now,
  }) {
    final end = data['currentPeriodEnd'];
    return DeepBlueMembershipSnapshot(
      active: data['active'] == true,
      status: data['status'] is String ? data['status']! as String : 'none',
      plan: data['plan'] is String ? data['plan']! as String : null,
      currentPeriodEnd: end is num
          ? DateTime.fromMillisecondsSinceEpoch(end.toInt() * 1000, isUtc: true)
          : null,
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] == true,
      checkedAt: now,
    );
  }

  Map<String, Object?> toJson() => {
    'active': active,
    'status': status,
    'plan': plan,
    'currentPeriodEnd': currentPeriodEnd?.toUtc().toIso8601String(),
    'cancelAtPeriodEnd': cancelAtPeriodEnd,
    'checkedAt': checkedAt?.toUtc().toIso8601String(),
  };

  factory DeepBlueMembershipSnapshot.fromJson(Map<String, Object?> j) =>
      DeepBlueMembershipSnapshot(
        active: j['active'] == true,
        status: j['status'] as String? ?? 'none',
        plan: j['plan'] as String?,
        currentPeriodEnd: DateTime.tryParse(j['currentPeriodEnd'] as String? ?? ''),
        cancelAtPeriodEnd: j['cancelAtPeriodEnd'] == true,
        checkedAt: DateTime.tryParse(j['checkedAt'] as String? ?? ''),
      );

  @override
  bool operator ==(Object other) =>
      other is DeepBlueMembershipSnapshot &&
      other.active == active &&
      other.status == status &&
      other.plan == plan &&
      other.currentPeriodEnd == currentPeriodEnd &&
      other.cancelAtPeriodEnd == cancelAtPeriodEnd &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(
    active,
    status,
    plan,
    currentPeriodEnd,
    cancelAtPeriodEnd,
    checkedAt,
  );
}

/// The one premium rule every app uses: its own store purchase, or a live
/// DeepBlue All Access membership. A store purchase never unlocks other apps;
/// the membership never touches the store purchase.
bool hasPremium({
  required bool individualAppPurchase,
  required bool deepBlueMembership,
}) => individualAppPurchase || deepBlueMembership;

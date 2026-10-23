import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';

/// The referral programme, backed by the callables in functions/referrals.
///
/// Everyone gets a code to share. A friend who enters it on the paywall gets
/// 50% off their first year of Annual; once friends subscribe with it, the
/// referrer earns [ReferralReward]s at 1, 2 and 3 friends. The server only
/// counts a friend after the store confirms the discounted purchase, which
/// [reportPurchase] forwards.
///
/// Referral records are keyed by Firebase uid. People who reach the paywall
/// without an account are signed in anonymously the first time they use a
/// code or open their own.
class ReferralController extends ChangeNotifier {
  ReferralController({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _authOverride = auth,
      _functionsOverride = functions;

  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'europe-west2');

  /// Set while the server is waiting on a purchase from this user: a friend
  /// discount to use, an Apple reward offer to redeem, or a Lifetime code.
  /// Keeps [reportPurchase] from calling the server on every launch.
  static const _kAwaitingPurchase = 'referral.awaiting_purchase';

  ReferralStatus? _status;
  ReferralStatus? get status => _status;

  bool _loading = false;
  bool get isLoading => _loading;

  final Set<String> _reported = {};

  static String get _platform => StorePlatform.isAndroid ? 'android' : 'ios';

  /// Whether a friend's code has been accepted and not used yet.
  bool get hasFriendDiscount =>
      _status?.friendDiscount?.state == FriendDiscountState.available;

  /// Fetches the user's code and progress. Without [createAccount], does
  /// nothing for someone with no Firebase account yet.
  Future<void> refresh({bool createAccount = false}) async {
    if (_auth.currentUser == null && !createAccount) return;
    _loading = true;
    notifyListeners();
    try {
      await _ensureSignedIn();
      await _setStatus(await _call('referralStatus'));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Sends a friend's code to the server. Throws [ReferralException] with a
  /// message to show if it isn't accepted.
  Future<void> applyCode(String code) async {
    await _ensureSignedIn();
    await _setStatus(await _call('applyReferralCode', {'code': code}));
    notifyListeners();
  }

  /// Hands a purchase to the server when it's waiting on one. The friend's
  /// discounted purchase is what earns the referrer their reward.
  Future<void> reportPurchase(PurchaseDetails purchase) async {
    final verification = purchase.verificationData.serverVerificationData;
    if (verification.isEmpty || !_reported.add(verification)) return;
    if (_auth.currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAwaitingPurchase) != true) return;
      await _setStatus(
        await _call('recordPurchase', {
          'productId': purchase.productID,
          'verificationData': verification,
        }),
      );
      notifyListeners();
    } catch (error) {
      // Try again with the next purchase update (every launch restores).
      _reported.remove(verification);
      debugPrint('ReferralController: reporting purchase failed — $error');
    }
  }

  /// Claims an earned reward. Pass the user's current subscription so the
  /// server knows what to apply it to.
  Future<RewardClaim> claim(
    ReferralReward reward, {
    PaywallPlan? plan,
    String? verificationData,
  }) async {
    final result = await _call('claimReferralReward', {
      'reward': reward.id,
      'plan': ?switch (plan) {
        PaywallPlan.weekly => 'weekly',
        PaywallPlan.yearly => 'yearly',
        null => null,
      },
      'verificationData': ?verificationData,
    });
    await _setStatus(Map<String, dynamic>.from(result['status'] as Map));
    notifyListeners();
    return switch (result['kind']) {
      'promotionalOffer' => RewardClaim.promotionalOffer(
        _offerFrom(Map<String, dynamic>.from(result['offer'] as Map)),
      ),
      'deferred' => RewardClaim.deferred(
        DateTime.tryParse(result['renewsAt'] as String? ?? ''),
      ),
      'scheduled' => RewardClaim.scheduled(
        DateTime.tryParse(result['appliesAt'] as String? ?? ''),
      ),
      _ => RewardClaim.code(
        result['code'] as String,
        Uri.parse(result['redeemUrl'] as String),
      ),
    };
  }

  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      debugPrint('ReferralController: anonymous sign-in failed — $error');
      throw const ReferralException(
        "Couldn't reach the server. Check your connection and try again.",
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>({
        'platform': _platform,
        ...data,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'ReferralController: $name failed — ${error.code} ${error.message}',
      );
      throw ReferralException(_messageFor(error));
    }
  }

  static String _messageFor(FirebaseFunctionsException error) => switch ((
    error.code,
    error.message,
  )) {
    ('not-found', _) => "That code doesn't exist. Check it and try again.",
    (_, 'own-code') => "That's your own code. Share it with a friend instead.",
    (_, 'already-applied') => "You've already used a friend's code.",
    (_, 'already-redeemed') => 'This reward has already been claimed.',
    (_, 'not-active') =>
      'This reward needs an active subscription to apply to.',
    (_, 'no-codes') =>
      "We're out of Lifetime codes right now. We've been told, so try "
          'again in a day or two.',
    ('unavailable' || 'deadline-exceeded' || 'internal', _) =>
      "Couldn't reach the server. Check your connection and try again.",
    _ => 'Something went wrong. Please try again.',
  };

  Future<void> _setStatus(Map<String, dynamic> json) async {
    _status = ReferralStatus.fromJson(json);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAwaitingPurchase, _status!.awaitsPurchase);
    } catch (error) {
      debugPrint('ReferralController: saving state failed — $error');
    }
  }

  static SignedPromotionalOffer _offerFrom(Map<String, dynamic> json) => (
    productId: json['productId'] as String,
    offerId: json['offerId'] as String,
    keyId: json['keyId'] as String,
    nonce: json['nonce'] as String,
    timestamp: (json['timestamp'] as num).toInt(),
    signature: json['signature'] as String,
  );
}

/// A failure with a message ready to show the user.
class ReferralException implements Exception {
  const ReferralException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum ReferralReward {
  halfOffYear('half_1y'),
  freeYear('free_1y'),
  lifetime('lifetime');

  const ReferralReward(this.id);
  final String id;

  static ReferralReward? fromId(String id) =>
      values.where((r) => r.id == id).firstOrNull;
}

enum RewardState {
  locked,
  earned,

  /// Android only: the server is pushing the renewal back right now.
  redeeming,

  /// Android only: claimed, and the free days are added on
  /// [ReferralTier.appliesAt] if the subscription is still active then.
  scheduled,

  /// Lifetime only: a code was handed out and hasn't been redeemed yet.
  codeIssued,
  redeemed;

  static RewardState fromId(String? id) =>
      values.where((s) => s.name == id).firstOrNull ?? locked;
}

enum FriendDiscountState { available, used }

@immutable
class ReferralTier {
  const ReferralTier({
    required this.reward,
    required this.friends,
    required this.state,
    this.code,
    this.redeemUrl,
    this.appliesAt,
  });

  final ReferralReward reward;

  /// Friends who must subscribe with the user's code to earn [reward].
  final int friends;
  final RewardState state;

  /// The Lifetime code and where to redeem it, once handed out.
  final String? code;
  final Uri? redeemUrl;

  /// When a scheduled reward's free days are added.
  final DateTime? appliesAt;
}

@immutable
class ReferralStatus {
  const ReferralStatus({
    required this.code,
    required this.friends,
    required this.tiers,
    this.pendingFriends = 0,
    this.holdDays = 14,
    this.friendDiscount,
  });

  factory ReferralStatus.fromJson(Map<String, dynamic> json) {
    final discount = json['friendDiscount'] as Map?;
    return ReferralStatus(
      code: json['code'] as String,
      friends: (json['friends'] as num?)?.toInt() ?? 0,
      pendingFriends: (json['pendingFriends'] as num?)?.toInt() ?? 0,
      holdDays: (json['holdDays'] as num?)?.toInt() ?? 14,
      tiers: [
        for (final raw in json['tiers'] as List)
          if (ReferralReward.fromId((raw as Map)['reward'] as String)
              case final reward?)
            ReferralTier(
              reward: reward,
              friends: (raw['friends'] as num).toInt(),
              state: RewardState.fromId(raw['state'] as String?),
              code: raw['code'] as String?,
              redeemUrl: raw['redeemUrl'] == null
                  ? null
                  : Uri.parse(raw['redeemUrl'] as String),
              appliesAt: DateTime.tryParse(raw['appliesAt'] as String? ?? ''),
            ),
      ],
      friendDiscount: discount == null
          ? null
          : (
              code: discount['code'] as String,
              state: discount['state'] == 'used'
                  ? FriendDiscountState.used
                  : FriendDiscountState.available,
            ),
    );
  }

  /// The user's own code to share.
  final String code;

  /// Friends who have subscribed with [code] and are past the hold.
  final int friends;

  /// Friends who subscribed with [code] less than [holdDays] ago. They count
  /// once the hold is over, unless they're refunded.
  final int pendingFriends;
  final int holdDays;
  final List<ReferralTier> tiers;

  /// The friend's code this user entered, if any.
  final ({String code, FriendDiscountState state})? friendDiscount;

  /// Whether the server is waiting on a purchase from this user.
  bool get awaitsPurchase =>
      friendDiscount?.state == FriendDiscountState.available ||
      tiers.any(
        (t) =>
            t.state == RewardState.codeIssued ||
            (!StorePlatform.isAndroid && t.state == RewardState.earned),
      );
}

/// What claiming a reward handed back.
sealed class RewardClaim {
  const RewardClaim();
  const factory RewardClaim.promotionalOffer(SignedPromotionalOffer offer) =
      PromotionalOfferClaim;
  const factory RewardClaim.deferred(DateTime? renewsAt) = DeferredClaim;
  const factory RewardClaim.scheduled(DateTime? appliesAt) = ScheduledClaim;
  const factory RewardClaim.code(String code, Uri redeemUrl) = CodeClaim;
}

/// iOS: an offer to buy with [PurchaseController.purchaseWithPromotionalOffer].
class PromotionalOfferClaim extends RewardClaim {
  const PromotionalOfferClaim(this.offer);
  final SignedPromotionalOffer offer;
}

/// Android: the next renewal has been pushed back to [renewsAt].
class DeferredClaim extends RewardClaim {
  const DeferredClaim(this.renewsAt);
  final DateTime? renewsAt;
}

/// Android: the free days are added on [appliesAt], after a paid stretch,
/// as long as the subscription is still active then.
class ScheduledClaim extends RewardClaim {
  const ScheduledClaim(this.appliesAt);
  final DateTime? appliesAt;
}

/// Lifetime: a single-use code to redeem in the store.
class CodeClaim extends RewardClaim {
  const CodeClaim(this.code, this.redeemUrl);
  final String code;
  final Uri redeemUrl;
}

// GENERATED from ViralEngine/funnel-kit/dart/funnel_purchases.dart — edit it there and run `npm run funnel:sync`.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'funnel_tracker.dart';
import 'install_attribution.dart';

/// Sends every purchase the store reports to the server's purchase check
/// (the verifyStorePurchase callable), which verifies it with Apple or
/// Google, records it once per store transaction id in the commerce ledger,
/// and says whether it was a trial, a paid purchase or a renewal. Only then
/// does [FunnelTracker] log trial_start / purchase_verified.
///
/// Restored purchases go to the server once per install, so the ledger
/// learns about subscribers from before it existed, but they're never
/// logged as acquisitions. A check that fails (offline) is retried on the
/// next launch.
class FunnelPurchaseReporter {
  FunnelPurchaseReporter({
    required FunnelTracker tracker,
    String region = 'europe-west2',
    FirebaseFunctions? functions,
  }) : _tracker = tracker,
       _region = region,
       _functionsOverride = functions;

  final FunnelTracker _tracker;
  final String _region;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instanceFor(region: _region);

  static const _kRestoresSent = 'funnel.restores_sent.v1';
  static const _kPending = 'funnel.pending_checks.v1';

  /// Purchases sent this session (the stream repeats them).
  final Set<String> _sent = {};
  bool _retried = false;

  /// Hand every purchased/restored update here (after access is granted).
  Future<void> report(PurchaseDetails p, {String? placement}) async {
    final data = p.verificationData.serverVerificationData;
    if (data.isEmpty) return;
    final restored = p.status == PurchaseStatus.restored;
    final key = _hash(data);
    if (!_sent.add(key)) return;
    final prefs = await SharedPreferences.getInstance();
    final restoresSent = prefs.getStringList(_kRestoresSent) ?? <String>[];
    if (restored && restoresSent.contains(key)) return;

    final check = <String, Object?>{
      'platform': defaultTargetPlatform == TargetPlatform.android
          ? 'android'
          : 'ios',
      'productId': p.productID,
      'verificationData': data,
      'status': restored ? 'restored' : 'purchased',
      'placement': placement,
      // The post that brought the install (Android), for the ledger.
      'postCode': InstallAttribution.instance.postCode,
    };
    final ok = await _send(check);
    if (ok && restored) {
      restoresSent.add(key);
      if (restoresSent.length > 100) restoresSent.removeAt(0);
      await prefs.setStringList(_kRestoresSent, restoresSent);
    }
    if (!ok && !restored) await _queue(prefs, check);
    unawaited(retryPending());
  }

  /// Re-sends purchase checks that failed earlier. Safe to call often.
  Future<void> retryPending() async {
    if (_retried) return;
    _retried = true;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_kPending) ?? const <String>[];
    if (pending.isEmpty) return;
    final left = <String>[];
    for (final raw in pending) {
      final check = Map<String, Object?>.from(jsonDecode(raw) as Map);
      if (!await _send(check)) left.add(raw);
    }
    await prefs.setStringList(_kPending, left);
  }

  Future<bool> _send(Map<String, Object?> check) async {
    try {
      final result = await _functions
          .httpsCallable('verifyStorePurchase')
          .call<Object?>({
            ...check,
            'appInstanceId': await _tracker.appInstanceIdIfConsented(),
          });
      final body = Map<String, dynamic>.from(result.data as Map);
      if (body['verified'] == true) {
        _tracker.recordVerified(VerifiedPurchase.fromJson(body));
      }
      // A purchase the store doesn't vouch for isn't retried.
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[funnel] purchase check failed: ${e.code} ${e.message}');
      if (e.code == 'permission-denied' || e.code == 'invalid-argument') {
        _tracker.purchaseFailed(
          productId: check['productId'] as String? ?? '',
          category: PurchaseFailure.verification,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[funnel] purchase check failed: $e');
      return false;
    }
  }

  Future<void> _queue(
    SharedPreferences prefs,
    Map<String, Object?> check,
  ) async {
    final pending = prefs.getStringList(_kPending) ?? <String>[];
    pending.add(jsonEncode(check));
    while (pending.length > 5) {
      pending.removeAt(0);
    }
    await prefs.setStringList(_kPending, pending);
  }

  /// A short stable key: the tail of a JWS is its signature, and a Play
  /// purchase token is unique throughout.
  String _hash(String s) => s.length > 64 ? s.substring(s.length - 64) : s;
}

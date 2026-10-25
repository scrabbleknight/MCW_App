// GENERATED from ViralEngine/funnel-kit/dart/install_attribution.dart — edit it there and run `npm run funnel:sync`.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The social post that brought this install, for revenue attribution
/// (ViralEngine/ATTRIBUTION.md → "Revenue attribution"). Android only:
/// iOS has no install referrer.
///
/// The smart-link pages send Play installs with a referrer like
/// `utm_source=tiktok&utm_medium=post&utm_campaign=p_t3k9x2a&utm_content=t3k9x2a`.
/// On first launch this reads it once, keeps only the post code (a platform
/// letter plus 6 characters), and every Play purchase then carries
/// `obfuscatedProfileId: "ve_<code>"`. Post-Bridge reads that back from
/// Play (analytics/playrtdn.js → acq_code) and joins trials and purchases
/// to the post.
///
/// Play rejects a purchase that has a profile id but no account id ("Something
/// went wrong on our end"), so such purchases also carry
/// [obfuscatedAccountId]: a random id made for this install, unless the app
/// already passes its own (referral accounts in Glance and PistePath).
///
/// The code identifies a post, not a person, so it doesn't wait for
/// analytics consent. Bio-link and organic installs have no code.
class InstallAttribution {
  InstallAttribution._();

  static final InstallAttribution instance = InstallAttribution._();

  static const _kCode = 'funnel.post_code.v1';
  static const _kChecked = 'funnel.referrer_checked.v1';
  static const _kAttempts = 'funnel.referrer_attempts.v1';
  static const _kAccount = 'funnel.install_account.v1';

  /// Play keeps the referrer for 90 days; a few launches is plenty to
  /// get past a Play Store that's updating or not ready.
  static const _maxAttempts = 5;

  /// Debug builds only: pretend Play returned this referrer, e.g.
  /// `--dart-define=VE_TEST_REFERRER=utm_content=f3hnfms`.
  static const _testReferrer = String.fromEnvironment('VE_TEST_REFERRER');

  static final _code = RegExp(r'^[tify][a-z0-9]{6}$');

  String? _postCode;
  String? _accountId;
  bool _loaded = false;

  /// The post code, e.g. `f3hnfms`, or null (no post, iOS, not read yet).
  String? get postCode => _postCode;

  /// For `GooglePlayPurchaseParam(obfuscatedProfileId: ...)`.
  String? get obfuscatedProfileId =>
      _postCode == null ? null : 've_$_postCode';

  /// For `applicationUserName` (Play's obfuscated account id) when the app
  /// has none of its own: Play needs one whenever a profile id is set.
  /// Random, made once per install, and null when there's no post code.
  String? get obfuscatedAccountId => _postCode == null ? null : _accountId;

  /// Call once at startup. Cheap after the first successful read.
  Future<void> load({
    @visibleForTesting Future<String?> Function()? readReferrer,
    @visibleForTesting bool? isAndroid,
  }) async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _postCode = prefs.getString(_kCode);
      _accountId = prefs.getString(_kAccount);
      if (_accountId == null) {
        final r = Random.secure();
        _accountId = List.generate(
          16,
          (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        await prefs.setString(_kAccount, _accountId!);
      }
      if (kDebugMode && _testReferrer.isNotEmpty) {
        _postCode = parse(_testReferrer);
        debugPrint('[funnel] test referrer → post code $_postCode');
        return;
      }
      final android =
          isAndroid ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
      if (!android || prefs.getBool(_kChecked) == true) return;
      final attempts = (prefs.getInt(_kAttempts) ?? 0) + 1;
      await prefs.setInt(_kAttempts, attempts);
      final String? referrer;
      try {
        referrer = await (readReferrer ?? _readPlay)();
      } catch (e) {
        // Play Store missing or busy: try again next launch, up to a limit.
        debugPrint('[funnel] install referrer unavailable: $e');
        if (attempts >= _maxAttempts) await prefs.setBool(_kChecked, true);
        return;
      }
      await prefs.setBool(_kChecked, true);
      if (kDebugMode) debugPrint('[funnel] Play install referrer: $referrer');
      final code = parse(referrer);
      if (code == null) return;
      _postCode = code;
      await prefs.setString(_kCode, code);
      debugPrint('[funnel] installed from post $code');
    } catch (e) {
      debugPrint('[funnel] install attribution failed: $e');
    }
  }

  static Future<String?> _readPlay() async =>
      (await PlayInstallReferrer.installReferrer).installReferrer;

  /// The post code in a Play referrer string: `utm_content`, or the
  /// `p_<code>` campaign. Null for organic, bio-link or anything else.
  @visibleForTesting
  static String? parse(String? referrer) {
    if (referrer == null || referrer.trim().isEmpty) return null;
    var q = referrer.trim();
    // Some sources pass it still URL-encoded.
    if (!q.contains('=') && q.contains('%3D')) q = Uri.decodeComponent(q);
    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(q);
    } catch (_) {
      return null;
    }
    final content = params['utm_content']?.trim().toLowerCase();
    if (content != null && _code.hasMatch(content)) return content;
    final campaign = params['utm_campaign']?.trim().toLowerCase() ?? '';
    if (campaign.startsWith('p_') && _code.hasMatch(campaign.substring(2))) {
      return campaign.substring(2);
    }
    return null;
  }

  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _postCode = null;
    _accountId = null;
  }
}

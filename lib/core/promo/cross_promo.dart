import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Picked for you" ad for one of our other apps, shown once per device —
/// when the user finishes Day 2, or for users who were already past Day 2
/// when this shipped, their second session after it (see
/// [CrossPromo.shouldShowAfterSession]).
/// The artwork is a single image with its own close (X) and call
/// to action baked in: the X corner closes the popup, anywhere else opens
/// the App Store (or, on Android, Google Play) listing. On Android the ad is
/// skipped entirely unless [CrossPromoAd.playStorePackage] is set.
///
/// This file is shared verbatim between our apps — keep it free of
/// app-specific imports.
class CrossPromoAd {
  const CrossPromoAd({
    required this.id,
    required this.imageAsset,
    required this.appStoreId,
    required this.semanticLabel,
    this.playStorePackage,
  });

  /// Stable key for remembering that it has been shown.
  final String id;
  final String imageAsset;
  final String appStoreId;
  final String semanticLabel;

  /// Android application ID of the promoted app, or null if it isn't on
  /// Google Play.
  final String? playStorePackage;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get isAvailable => !_isAndroid || playStorePackage != null;

  Uri get storeUri => _isAndroid
      ? Uri.parse(
          'https://play.google.com/store/apps/details?id=$playStorePackage',
        )
      : Uri.parse('https://apps.apple.com/app/id$appStoreId');

  String get storeName => _isAndroid ? 'Google Play' : 'the App Store';
}

abstract final class CrossPromo {
  static String _shownKey(CrossPromoAd ad) => 'cross_promo_shown_${ad.id}';
  static const _modeKey = 'cross_promo_mode';
  static const _countKey = 'cross_promo_sessions_since_update';

  /// Call once per completed session, with the state from *before* it was
  /// recorded. Returns whether this completion should trigger the ad.
  ///
  /// The first call fixes the user's mode for good:
  ///  * new users (Day 2 not yet done) see it when they first finish Day 2;
  ///  * users who were already past Day 2 when this code shipped see it on
  ///    the second session they complete from then on.
  static Future<bool> shouldShowAfterSession({
    required bool day2WasDone,
    required bool completesDay2,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var mode = prefs.getString(_modeKey);
      if (mode == null) {
        mode = day2WasDone ? 'existing' : 'new';
        await prefs.setString(_modeKey, mode);
      }
      if (mode == 'new') return completesDay2;
      final count = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, count);
      return count == 2;
    } catch (_) {
      return false;
    }
  }

  /// Shows [ad] once the screen is settled — unless it has been shown on
  /// this device before (it only ever appears once). With [waitForFirstRoute], waits
  /// until [navigator] is back on its first route with nothing on top (e.g.
  /// a celebration modal has been closed).
  static Future<void> showWhenIdle(
    NavigatorState navigator,
    CrossPromoAd ad, {
    bool waitForFirstRoute = true,
    Duration initialDelay = const Duration(milliseconds: 900),
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!ad.isAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_shownKey(ad)) ?? false) return;
    } catch (_) {}

    await Future<void>.delayed(initialDelay);
    final deadline = DateTime.now().add(timeout);
    while (waitForFirstRoute && navigator.mounted && navigator.canPop()) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!navigator.mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shownKey(ad), true);
    } catch (_) {}
    if (!navigator.mounted) return;
    await show(navigator.context, ad);
  }

  static Future<void> show(BuildContext context, CrossPromoAd ad) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, _, _) => _PromoCard(ad: ad),
    );
  }

  static Future<void> _openStore(BuildContext context, CrossPromoAd ad) async {
    Navigator.of(context).pop();
    await launchUrl(ad.storeUri, mode: LaunchMode.externalApplication);
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.ad});

  final CrossPromoAd ad;

  /// Artwork is 949 × 1658.
  static const _aspect = 949 / 1658;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: AspectRatio(
            aspectRatio: _aspect,
            child: LayoutBuilder(
              builder: (context, box) {
                // Corners of the artwork are flat-filled; round them off.
                final radius = box.maxWidth * 0.06;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      button: true,
                      label: ad.semanticLabel,
                      hint: 'Opens ${ad.storeName}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => CrossPromo._openStore(context, ad),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: Image.asset(ad.imageAsset, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    // Hit area over the X drawn in the artwork's top-right.
                    Positioned(
                      top: 0,
                      right: 0,
                      width: box.maxWidth * 0.2,
                      height: box.maxWidth * 0.2,
                      child: Semantics(
                        button: true,
                        label: 'Close',
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

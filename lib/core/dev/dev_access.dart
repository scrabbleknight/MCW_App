import 'package:flutter/foundation.dart';

/// Decides whether the running build is a developer build, so the
/// subscription gate stays out of the way while developing.
///
/// Both triggers are baked in at *build time*:
///
/// 1. **[kDebugMode]** — true for `flutter run` / debug builds; always false
///    in a release build from the App Store or Google Play.
/// 2. **[_devSkipFlag]** — opt in on a release build you install yourself
///    with `--dart-define=MCW_DEV_SKIP=true`. A store build compiled without
///    the flag can't turn it on.
abstract final class DevAccess {
  static const _devSkipFlag = bool.fromEnvironment(
    'MCW_DEV_SKIP',
    defaultValue: false,
  );

  static bool get isDeveloper => kDebugMode || _devSkipFlag;
}

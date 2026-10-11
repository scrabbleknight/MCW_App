import 'package:firebase_auth/firebase_auth.dart';

/// Store reviewers can't buy subscriptions or start free trials, so the test
/// account we give them (Play Console → App content → Sign in details) gets
/// full access without a purchase.
///
/// The account is a Firebase test phone number, so signing in needs its fixed
/// code rather than a real SMS. Anyone who learned both could also get in for
/// free: if they leak, change the test number in Firebase, Play Console and
/// here.
abstract final class ReviewAccess {
  static const _reviewPhoneNumbers = {'+447111111222'};

  /// True when the signed-in Firebase user is the store review account.
  static bool get isReviewAccount {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    return phone != null && _reviewPhoneNumbers.contains(phone);
  }
}

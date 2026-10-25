const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const referrals = require('./referrals');

initializeApp();

/**
 * Deletes the signed-in caller's account and the workout feedback stored
 * under it (session_feedback/{uid}, quit_feedback/{uid}), plus their
 * referral record (functions/referrals).
 *
 * Deleting from the app itself needs a sign-in from the last few minutes,
 * which forces users to sign in again just to delete. The Admin SDK has no
 * such rule, and the callable proves who the caller is from their ID token,
 * so it only ever deletes the caller's own data.
 *
 * Everything else lives on the phone, and the app erases it after this
 * succeeds. Called from AuthService.deleteCurrentAccount
 * (lib/features/auth/application/auth_service.dart).
 */
exports.deleteAccount = onCall({ region: 'europe-west2' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in to delete your account.');
  }
  const db = getFirestore();
  for (const collection of ['session_feedback', 'quit_feedback']) {
    await db.recursiveDelete(db.collection(collection).doc(uid));
  }
  await referrals.deleteReferralData(uid);
  await getAuth().deleteUser(uid);
  return { deleted: true };
});

// Referral programme: codes, friend discount and referrer rewards.
exports.referralStatus = referrals.referralStatus;
exports.applyReferralCode = referrals.applyReferralCode;
exports.recordPurchase = referrals.recordPurchase;
exports.claimReferralReward = referrals.claimReferralReward;
exports.checkRewardCodes = referrals.checkRewardCodes;
exports.applyScheduledRewards = referrals.applyScheduledRewards;
exports.confirmReferrals = referrals.confirmReferrals;

// Commerce ledger for the funnel: verified purchases and App Store
// subscription lifecycle (shared code from ViralEngine/funnel-kit).
const commerce = require('./commerce');
exports.verifyStorePurchase = commerce.verifyStorePurchase;
exports.appStoreNotifications = commerce.appStoreNotifications;

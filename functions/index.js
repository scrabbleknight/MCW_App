const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

/**
 * Deletes the signed-in caller's account and the workout feedback stored
 * under it (session_feedback/{uid}, quit_feedback/{uid}).
 *
 * Deleting from the app itself needs a sign-in from the last few minutes,
 * which forces users to sign in again just to delete. The Admin SDK has no
 * such rule, and the callable proves who the caller is from their ID token,
 * so it only ever deletes the caller's own data.
 *
 * Everything else lives on the phone, and the app erases it after this
 * succeeds.
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
  await getAuth().deleteUser(uid);
  return { deleted: true };
});

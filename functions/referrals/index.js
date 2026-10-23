const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineBoolean, defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const {
  TIERS,
  REFERRAL_HOLD_DAYS,
  SUBSCRIPTIONS,
  IOS_PROMO_OFFERS,
  ANDROID_DEFER_DAYS,
  ANDROID_DEFER_AFTER_DAYS,
  LIFETIME,
  REGION,
} = require('./config');
const {
  generateCode,
  normalizeCode,
  planForProduct,
  isFriendPurchase,
  rewardForPromoOffer,
  rewardsEarned,
  redeemUrl,
  purchaseKey,
} = require('./logic');
const stores = require('./stores');

/**
 * Referral programme. Each user gets a code to share; a friend who enters it
 * on the paywall gets 50% off their first year, and the referrer earns a
 * reward at 1, 2 and 3 friends who subscribed with it (see config.TIERS).
 *
 * A friend only counts once the store confirms they bought with the referral
 * discount, so typing a code in on a spare account earns nothing, and only
 * after a REFERRAL_HOLD_DAYS hold without a refund. Every
 * reward is delivered through the store: Apple promotional offers and Play
 * renewal deferrals for the subscription rewards, single-use codes for the
 * Lifetime product.
 *
 * Firestore (server-only, see firestore.rules):
 *   referralCodes/{code}     → { uid }
 *   referralUsers/{uid}      → { code, referredBy, friendPurchaseAt,
 *                                friends, pendingFriends,
 *                                rewards: { [reward]: {...} } }
 *   referralPurchases/{key}  → one per store purchase that qualified a friend,
 *                                state pending → confirmed | refunded
 *   rewardCodes/{id}         → { platform, code, assignedTo } Lifetime codes
 */

const APPLE_IAP_KEY = defineSecret('APPLE_IAP_KEY');
const APPLE_IAP_KEY_ID = defineSecret('APPLE_IAP_KEY_ID');
const APPLE_IAP_ISSUER_ID = defineSecret('APPLE_IAP_ISSUER_ID');

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Lets Xcode/TestFlight sandbox and Play license-tester purchases count.
 * They're free, so leave this off in production except while testing.
 */
const ALLOW_TEST_PURCHASES = defineBoolean('ALLOW_TEST_PURCHASES', {
  default: false,
});

const db = () => getFirestore();
const users = () => db().collection('referralUsers');
const codes = () => db().collection('referralCodes');

const PLATFORMS = ['ios', 'android'];

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  return uid;
}

function requirePlatform(value) {
  if (!PLATFORMS.includes(value)) {
    throw new HttpsError('invalid-argument', 'Unknown platform.');
  }
  return value;
}

function requireString(value, name) {
  if (typeof value !== 'string' || value.length === 0 || value.length > 20000) {
    throw new HttpsError('invalid-argument', `Missing ${name}.`);
  }
  return value;
}

/**
 * Gives [uid] a referral code if they don't have one yet, inside [tx].
 * Returns the user's data as it will be once [tx] commits.
 */
async function ensureUser(tx, uid) {
  const ref = users().doc(uid);
  const snap = await tx.get(ref);
  const data = snap.exists ? snap.data() : {};
  if (data.code) return { ref, data };

  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateCode();
    const codeRef = codes().doc(code);
    if ((await tx.get(codeRef)).exists) continue;
    tx.set(codeRef, { uid, createdAt: FieldValue.serverTimestamp() });
    const fresh = {
      friends: 0,
      rewards: {},
      referredBy: null,
      ...data,
      code,
      createdAt: FieldValue.serverTimestamp(),
    };
    tx.set(ref, fresh, { merge: true });
    return { ref, data: fresh };
  }
  throw new HttpsError('internal', 'Could not create a referral code.');
}

/** What the app shows: the user's code, progress and each reward's state. */
function statusOf(data, platform) {
  const rewards = data.rewards ?? {};
  return {
    code: data.code,
    friends: data.friends ?? 0,
    pendingFriends: Math.max(data.pendingFriends ?? 0, 0),
    holdDays: REFERRAL_HOLD_DAYS,
    tiers: TIERS.map(({ reward, friends }) => {
      const r = rewards[reward];
      // An issued code that expired unredeemed can be claimed again.
      const expired = r?.state === 'codeIssued' && !codeStillValid(r);
      const tier = {
        reward,
        friends,
        state: expired ? 'earned' : r?.state ?? 'locked',
      };
      if (r?.code && r.platform === platform && !expired) {
        tier.code = r.code;
        tier.redeemUrl = redeemUrl(platform, r.code);
      }
      if (r?.state === 'scheduled') {
        tier.appliesAt = new Date(millisOf(r.scheduledFor)).toISOString();
      }
      return tier;
    }),
    friendDiscount: data.referredBy
      ? {
          code: data.referredBy.code,
          state: data.friendPurchaseAt ? 'used' : 'available',
        }
      : null,
  };
}

/** Returns the caller's referral code and progress, creating the code. */
exports.referralStatus = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const platform = requirePlatform(request.data?.platform);
  const data = await db().runTransaction(
    async (tx) => (await ensureUser(tx, uid)).data,
  );
  return statusOf(data, platform);
});

/**
 * Attaches a friend's code to the caller so the paywall can offer the friend
 * discount. Nothing is earned until the caller subscribes with it.
 */
exports.applyReferralCode = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const platform = requirePlatform(request.data?.platform);
  const code = normalizeCode(request.data?.code);
  if (!code) {
    throw new HttpsError('not-found', "That code doesn't exist.");
  }

  const data = await db().runTransaction(async (tx) => {
    const codeSnap = await tx.get(codes().doc(code));
    const { ref, data } = await ensureUser(tx, uid);
    if (!codeSnap.exists) {
      throw new HttpsError('not-found', "That code doesn't exist.");
    }
    if (codeSnap.data().uid === uid) {
      throw new HttpsError('failed-precondition', 'own-code');
    }
    if (data.referredBy) {
      if (data.referredBy.code === code) return data;
      throw new HttpsError('already-exists', 'already-applied');
    }
    const referredBy = {
      uid: codeSnap.data().uid,
      code,
      at: FieldValue.serverTimestamp(),
    };
    tx.update(ref, { referredBy });
    return { ...data, referredBy };
  });
  return statusOf(data, platform);
});

async function verifyPurchase(platform, verificationData) {
  const allowTest = ALLOW_TEST_PURCHASES.value();
  try {
    return platform === 'ios'
      ? await stores.verifyAppleTransaction(verificationData, {
          allowSandbox: allowTest,
        })
      : await stores.verifyPlaySubscription(verificationData, { allowTest });
  } catch (error) {
    if (error instanceof stores.UntrustedPurchase) {
      logger.warn('Untrusted purchase', { platform, reason: error.message });
      throw new HttpsError('permission-denied', 'Purchase not verified.');
    }
    throw error;
  }
}

/**
 * The app calls this after a purchase while the caller has a friend
 * discount to use or a reward on its way. Verifies the purchase with the
 * store, then:
 *  - a friend discount purchase starts its hold, after which it counts
 *    towards the referrer's rewards (confirmReferrals);
 *  - an Apple promotional offer purchase marks that reward as redeemed;
 *  - a Lifetime purchase marks the Lifetime reward as redeemed.
 */
exports.recordPurchase = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const platform = requirePlatform(request.data?.platform);
  const verificationData = requireString(
    request.data?.verificationData,
    'verificationData',
  );
  // Android one-time products aren't subscriptions; the Lifetime code was
  // already handed out, and Play settles it, so there's nothing to check.
  if (platform === 'android' && request.data?.productId === LIFETIME.android) {
    return statusOf(await markLifetimeRedeemed(uid), platform);
  }

  const purchase = await verifyPurchase(platform, verificationData);
  if (platform === 'ios' && purchase.productId === LIFETIME.ios) {
    return statusOf(await markLifetimeRedeemed(uid), platform);
  }
  if (!planForProduct(platform, purchase.productId)) {
    throw new HttpsError('invalid-argument', 'Not a Military Calisthenics subscription.');
  }

  // Give the user a code first: a transaction can't read after it writes,
  // and ensureUser writes when it creates one.
  await db().runTransaction((tx) => ensureUser(tx, uid));
  const data = await db().runTransaction(async (tx) => {
    const ref = users().doc(uid);
    const data = (await tx.get(ref)).data();
    const promoReward =
      platform === 'ios' && purchase.offerType === 2
        ? rewardForPromoOffer(purchase.offerIdentifier)
        : null;
    const qualifies =
      isFriendPurchase(platform, purchase) &&
      data.referredBy &&
      !data.friendPurchaseAt;

    // Reads first: Firestore transactions can't read after writing.
    const keyRef = db()
      .collection('referralPurchases')
      .doc(purchaseKey(platform, purchase));
    const keySnap = qualifies ? await tx.get(keyRef) : null;
    const referrerRef = qualifies ? users().doc(data.referredBy.uid) : null;
    const referrerSnap = referrerRef ? await tx.get(referrerRef) : null;

    const updates = {};
    if (promoReward && data.rewards?.[promoReward]?.state === 'earned') {
      updates[`rewards.${promoReward}.state`] = 'redeemed';
      updates[`rewards.${promoReward}.redeemedAt`] =
        FieldValue.serverTimestamp();
      updates[`rewards.${promoReward}.method`] = 'apple-promotional-offer';
    }

    if (qualifies && !keySnap.exists && referrerSnap?.exists) {
      // Pending until the hold is over (confirmReferrals), so a refund in
      // that time earns the referrer nothing.
      tx.set(keyRef, {
        uid,
        referrerUid: data.referredBy.uid,
        platform,
        at: FieldValue.serverTimestamp(),
        state: 'pending',
        confirmsAt: new Date(Date.now() + REFERRAL_HOLD_DAYS * DAY_MS),
        ...(platform === 'ios'
          ? {
              transactionId: purchase.transactionId,
              environment: purchase.environment ?? null,
            }
          : { purchaseToken: purchase.purchaseToken }),
      });
      updates.friendPurchaseAt = FieldValue.serverTimestamp();
      tx.update(referrerRef, { pendingFriends: FieldValue.increment(1) });
      logger.info('Referral pending', {
        referrer: data.referredBy.uid,
        friend: uid,
      });
    }

    if (Object.keys(updates).length === 0) return data;
    tx.update(ref, updates);
    return applyDotted(data, updates);
  });
  return statusOf(data, platform);
});

async function markLifetimeRedeemed(uid) {
  return db().runTransaction(async (tx) => {
    const { ref, data } = await ensureUser(tx, uid);
    if (data.rewards?.lifetime?.state !== 'codeIssued') return data;
    const updates = {
      'rewards.lifetime.state': 'redeemed',
      'rewards.lifetime.redeemedAt': FieldValue.serverTimestamp(),
    };
    tx.update(ref, updates);
    return applyDotted(data, updates);
  });
}

/**
 * Hands over an earned reward.
 *  - Subscription rewards on iOS: a signed promotional offer for the plan
 *    the caller is on, which the app then buys. Apple applies it from the
 *    next renewal; recordPurchase marks it redeemed.
 *  - Subscription rewards on Android: pushes the caller's Play renewal back
 *    (ANDROID_DEFER_DAYS) straight away.
 *  - Lifetime: a single-use code for the Lifetime product, the same one on
 *    every call.
 */
exports.claimReferralReward = onCall(
  { region: REGION, secrets: [APPLE_IAP_KEY, APPLE_IAP_KEY_ID] },
  async (request) => {
    const uid = requireUid(request);
    const platform = requirePlatform(request.data?.platform);
    const reward = request.data?.reward;
    if (!TIERS.some((t) => t.reward === reward)) {
      throw new HttpsError('invalid-argument', 'Unknown reward.');
    }

    const snap = await users().doc(uid).get();
    const current = snap.data()?.rewards?.[reward];
    if (!current || current.state === 'locked') {
      throw new HttpsError('failed-precondition', 'not-earned');
    }

    if (reward === 'lifetime') {
      return claimLifetime(uid, platform);
    }
    if (current.state !== 'earned') {
      throw new HttpsError('failed-precondition', 'already-redeemed');
    }
    return platform === 'ios'
      ? claimApplePromo(uid, reward, request.data?.plan)
      : claimPlayDeferral(uid, reward, request.data?.verificationData);
  },
);

async function claimApplePromo(uid, reward, plan) {
  if (plan !== 'weekly' && plan !== 'yearly') {
    throw new HttpsError('invalid-argument', 'Unknown plan.');
  }
  const target = IOS_PROMO_OFFERS[reward][plan];
  const offer = stores.signPromotionalOffer({
    productId: SUBSCRIPTIONS.ios[target.plan],
    offerId: target.offerId,
    privateKey: APPLE_IAP_KEY.value(),
    keyId: APPLE_IAP_KEY_ID.value(),
  });
  const data = (await users().doc(uid).get()).data();
  return { kind: 'promotionalOffer', offer, status: statusOf(data, 'ios') };
}

async function claimPlayDeferral(uid, reward, purchaseToken) {
  requireString(purchaseToken, 'verificationData');
  const sub = await verifyPurchase('android', purchaseToken);
  if (!planForProduct('android', sub.productId)) {
    throw new HttpsError('invalid-argument', 'Not a Military Calisthenics subscription.');
  }
  if (sub.state !== 'SUBSCRIPTION_STATE_ACTIVE') {
    throw new HttpsError('failed-precondition', 'not-active');
  }
  const ref = users().doc(uid);

  const delayDays = ANDROID_DEFER_AFTER_DAYS[reward];
  if (delayDays) {
    const scheduledFor = new Date(Date.now() + delayDays * 24 * 60 * 60 * 1000);
    await db().runTransaction(async (tx) => {
      const data = (await tx.get(ref)).data();
      if (data?.rewards?.[reward]?.state !== 'earned') {
        throw new HttpsError('failed-precondition', 'already-redeemed');
      }
      tx.update(ref, {
        [`rewards.${reward}.state`]: 'scheduled',
        [`rewards.${reward}.scheduledFor`]: scheduledFor,
        [`rewards.${reward}.purchaseToken`]: purchaseToken,
      });
    });
    const data = (await ref.get()).data();
    return {
      kind: 'scheduled',
      appliesAt: scheduledFor.toISOString(),
      status: statusOf(data, 'android'),
    };
  }

  // Claim the reward before calling Play so two taps can't defer twice.
  await db().runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (data?.rewards?.[reward]?.state !== 'earned') {
      throw new HttpsError('failed-precondition', 'already-redeemed');
    }
    tx.update(ref, { [`rewards.${reward}.state`]: 'redeeming' });
  });

  let expiryTime;
  try {
    expiryTime = await stores.deferPlaySubscription({
      purchaseToken,
      etag: sub.etag,
      days: ANDROID_DEFER_DAYS[reward],
    });
  } catch (error) {
    logger.error('Play deferral failed', { uid, reward, error: String(error) });
    await ref.update({ [`rewards.${reward}.state`]: 'earned' });
    throw new HttpsError('unavailable', 'Google Play is unavailable.');
  }

  const updates = {
    [`rewards.${reward}.state`]: 'redeemed',
    [`rewards.${reward}.redeemedAt`]: FieldValue.serverTimestamp(),
    [`rewards.${reward}.method`]: 'play-deferral',
    [`rewards.${reward}.renewsAt`]: expiryTime,
  };
  await ref.update(updates);
  const data = (await ref.get()).data();
  return { kind: 'deferred', renewsAt: expiryTime, status: statusOf(data, 'android') };
}

/**
 * Daily: applies Android rewards that were scheduled for after a paid stretch
 * (ANDROID_DEFER_AFTER_DAYS). The subscription must still be active and
 * renewing; if it isn't (cancelled, expired, or replaced by a new purchase),
 * the reward goes back to "earned" so the user can claim it again once they
 * subscribe, starting a new paid stretch.
 */
exports.applyScheduledRewards = onSchedule(
  { region: REGION, schedule: 'every day 06:00', timeZone: 'Europe/London' },
  async () => {
    const now = Date.now();
    for (const reward of Object.keys(ANDROID_DEFER_AFTER_DAYS)) {
      const due = await users()
        .where(`rewards.${reward}.state`, '==', 'scheduled')
        .get();
      for (const doc of due.docs) {
        const r = doc.data().rewards[reward];
        if (millisOf(r.scheduledFor) > now) continue;
        await applyScheduledReward(doc.ref, reward, r);
      }
    }
  },
);

async function applyScheduledReward(ref, reward, r) {
  const backToEarned = async (why) => {
    logger.info('Scheduled reward not applied', { uid: ref.id, reward, why });
    await ref.update({
      [`rewards.${reward}.state`]: 'earned',
      [`rewards.${reward}.scheduledFor`]: FieldValue.delete(),
      [`rewards.${reward}.purchaseToken`]: FieldValue.delete(),
    });
  };
  let sub;
  try {
    sub = await stores.verifyPlaySubscription(r.purchaseToken, {
      allowTest: ALLOW_TEST_PURCHASES.value(),
    });
  } catch (error) {
    if (error instanceof stores.UntrustedPurchase) {
      return backToEarned(error.message);
    }
    logger.error('Scheduled reward check failed', {
      uid: ref.id,
      reward,
      error: String(error),
    });
    return; // Try again tomorrow.
  }
  if (sub.state !== 'SUBSCRIPTION_STATE_ACTIVE') return backToEarned(sub.state);

  try {
    const expiryTime = await stores.deferPlaySubscription({
      purchaseToken: r.purchaseToken,
      etag: sub.etag,
      days: ANDROID_DEFER_DAYS[reward],
    });
    await ref.update({
      [`rewards.${reward}.state`]: 'redeemed',
      [`rewards.${reward}.redeemedAt`]: FieldValue.serverTimestamp(),
      [`rewards.${reward}.method`]: 'play-deferral',
      [`rewards.${reward}.renewsAt`]: expiryTime,
    });
    logger.info('Scheduled reward applied', { uid: ref.id, reward, expiryTime });
  } catch (error) {
    logger.error('Play deferral failed', {
      uid: ref.id,
      reward,
      error: String(error),
    });
  }
}

/**
 * Daily: settles friend purchases whose hold (REFERRAL_HOLD_DAYS) is over.
 * One that was refunded in the hold is dropped; the rest count towards the
 * referrer's rewards. A purchase the stores can't be asked about yet waits
 * for the next run.
 */
exports.confirmReferrals = onSchedule(
  {
    region: REGION,
    schedule: 'every day 07:00',
    timeZone: 'Europe/London',
    secrets: [APPLE_IAP_KEY, APPLE_IAP_KEY_ID, APPLE_IAP_ISSUER_ID],
  },
  async () => {
    const now = Date.now();
    const pending = await db()
      .collection('referralPurchases')
      .where('state', '==', 'pending')
      .get();
    const due = pending.docs.filter(
      (doc) => millisOf(doc.data().confirmsAt) <= now,
    );

    let voided = null;
    if (due.some((doc) => doc.data().platform === 'android')) {
      try {
        // Play keeps voided purchases for 30 days.
        voided = await stores.playVoidedTokens(new Date(now - 30 * DAY_MS));
      } catch (error) {
        logger.error('Play voided purchases check failed', {
          error: String(error),
        });
      }
    }

    for (const doc of due) {
      let refunded;
      try {
        refunded = await purchaseRefunded(doc.data(), voided);
      } catch (error) {
        logger.error('Referral refund check failed', {
          purchase: doc.id,
          error: String(error),
        });
        continue; // Try again tomorrow.
      }
      await settleReferral(doc.ref, refunded);
    }
  },
);

async function purchaseRefunded(purchase, voided) {
  if (purchase.platform === 'ios') {
    return stores.appleTransactionRefunded(purchase, {
      privateKey: APPLE_IAP_KEY.value(),
      keyId: APPLE_IAP_KEY_ID.value(),
      issuerId: APPLE_IAP_ISSUER_ID.value(),
    });
  }
  if (!voided) throw new Error("Play's voided purchases are unavailable.");
  if (voided.has(purchase.purchaseToken)) return true;
  try {
    const sub = await stores.verifyPlaySubscription(purchase.purchaseToken, {
      allowTest: ALLOW_TEST_PURCHASES.value(),
    });
    // A year's subscription only ends this soon if it was revoked.
    return sub.state === 'SUBSCRIPTION_STATE_EXPIRED';
  } catch (error) {
    if (error instanceof stores.UntrustedPurchase) return true;
    throw error;
  }
}

async function settleReferral(ref, refunded) {
  await db().runTransaction(async (tx) => {
    const purchase = (await tx.get(ref)).data();
    if (purchase.state !== 'pending') return;
    // Null if the referrer has since deleted their account.
    const referrerRef = purchase.referrerUid
      ? users().doc(purchase.referrerUid)
      : null;
    const referrerSnap = referrerRef ? await tx.get(referrerRef) : null;

    tx.update(ref, {
      state: refunded ? 'refunded' : 'confirmed',
      settledAt: FieldValue.serverTimestamp(),
    });
    if (!referrerSnap?.exists) return;

    const referrer = referrerSnap.data();
    const updates = { pendingFriends: FieldValue.increment(-1) };
    if (!refunded) {
      const friends = (referrer.friends ?? 0) + 1;
      updates.friends = friends;
      for (const reward of rewardsEarned(friends)) {
        if (!referrer.rewards?.[reward]) {
          updates[`rewards.${reward}`] = {
            state: 'earned',
            earnedAt: FieldValue.serverTimestamp(),
          };
        }
      }
    }
    tx.update(referrerRef, updates);
    logger.info(refunded ? 'Referral refunded' : 'Referral confirmed', {
      referrer: purchase.referrerUid,
      friend: purchase.uid,
    });
  });
}

/**
 * A Lifetime code has to have at least this long left when it's handed out,
 * so the user has time to redeem it.
 */
const MIN_CODE_LIFE_MS = 7 * 24 * 60 * 60 * 1000;

function millisOf(value) {
  if (!value) return null;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return typeof value === 'number' ? value : null;
}

/** Whether an issued Lifetime code can still be redeemed. */
function codeStillValid(lifetime, now = Date.now()) {
  const expires = millisOf(lifetime?.codeExpiresAt);
  return expires == null || expires > now;
}

/**
 * Hands out a single-use Lifetime code from the pool. Apple's one-time codes
 * last at most 6 months, so the pool is topped up with fresh batches
 * (scripts/load-reward-codes.js) and each code carries its expiry. A user
 * whose code expired before they redeemed it gets a new one.
 */
async function claimLifetime(uid, platform) {
  const ref = users().doc(uid);
  const pool = db().collection('rewardCodes');
  const data = await db().runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    const lifetime = data.rewards.lifetime;
    if (lifetime.state === 'redeemed') {
      throw new HttpsError('failed-precondition', 'already-redeemed');
    }
    if (
      lifetime.code &&
      lifetime.platform === platform &&
      codeStillValid(lifetime)
    ) {
      return data;
    }

    const free = await tx.get(
      pool
        .where('platform', '==', platform)
        .where('assignedTo', '==', null)
        .where('expiresAt', '>', new Date(Date.now() + MIN_CODE_LIFE_MS))
        .orderBy('expiresAt')
        .limit(1),
    );
    if (free.empty) {
      logger.error('Lifetime reward codes have run out', { platform });
      throw new HttpsError('resource-exhausted', 'no-codes');
    }
    const codeDoc = free.docs[0];
    tx.update(codeDoc.ref, {
      assignedTo: uid,
      assignedAt: FieldValue.serverTimestamp(),
    });
    if (lifetime.code) {
      const oldRef = pool.doc(`${lifetime.platform}_${lifetime.code}`);
      // An expired code is dead. One for the other platform goes back in the
      // pool: the user switched phones before redeeming it.
      tx.update(
        oldRef,
        codeStillValid(lifetime)
          ? { assignedTo: null, assignedAt: null }
          : { expiredUnusedBy: uid },
      );
    }
    const updates = {
      'rewards.lifetime.state': 'codeIssued',
      'rewards.lifetime.code': codeDoc.data().code,
      'rewards.lifetime.platform': platform,
      'rewards.lifetime.codeExpiresAt': codeDoc.data().expiresAt,
      'rewards.lifetime.issuedAt': FieldValue.serverTimestamp(),
    };
    tx.update(ref, updates);
    return applyDotted(data, updates);
  });
  const status = statusOf(data, platform);
  const tier = status.tiers.find((t) => t.reward === 'lifetime');
  return { kind: 'code', code: tier.code, redeemUrl: tier.redeemUrl, status };
}

/**
 * Weekly check on the Lifetime code pools. Logs an error (alert on it in
 * Cloud Logging) when a platform has fewer than [LOW_CODES] codes that are
 * unassigned and valid for at least another 30 days: time to load a fresh
 * batch.
 */
const LOW_CODES = 10;
exports.checkRewardCodes = onSchedule(
  { region: REGION, schedule: 'every monday 09:00', timeZone: 'Europe/London' },
  async () => {
    const soon = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    for (const platform of PLATFORMS) {
      const usable = await db()
        .collection('rewardCodes')
        .where('platform', '==', platform)
        .where('assignedTo', '==', null)
        .where('expiresAt', '>', soon)
        .count()
        .get();
      const count = usable.data().count;
      if (count < LOW_CODES) {
        logger.error('Lifetime reward codes need topping up', {
          platform,
          usable: count,
        });
      } else {
        logger.info('Lifetime reward codes OK', { platform, usable: count });
      }
    }
  },
);

/**
 * [data] with Firestore-style dotted-path [updates] applied, for replies.
 * Copies each object on the way down so [data] itself is left alone.
 */
function applyDotted(data, updates) {
  const copy = { ...data };
  for (const [path, value] of Object.entries(updates)) {
    const keys = path.split('.');
    let node = copy;
    for (const key of keys.slice(0, -1)) {
      node[key] = { ...(node[key] ?? {}) };
      node = node[key];
    }
    node[keys.at(-1)] = value;
  }
  return copy;
}

/**
 * Removes [uid]'s referral record and code (called by deleteAccount). Their
 * qualified purchases stay, without the uid, so the same store purchase
 * can't qualify a friend again; a referrer's count isn't reduced.
 */
exports.deleteReferralData = async (uid) => {
  const ref = users().doc(uid);
  const snap = await ref.get();
  const batch = db().batch();
  if (snap.exists && snap.data().code) {
    batch.delete(codes().doc(snap.data().code));
  }
  batch.delete(ref);
  const purchases = await db()
    .collection('referralPurchases')
    .where('uid', '==', uid)
    .get();
  for (const doc of purchases.docs) batch.update(doc.ref, { uid: null });
  const asReferrer = await db()
    .collection('referralPurchases')
    .where('referrerUid', '==', uid)
    .get();
  for (const doc of asReferrer.docs) {
    batch.update(doc.ref, { referrerUid: null });
  }
  await batch.commit();
};

exports._test = { statusOf, applyDotted, codeStillValid };

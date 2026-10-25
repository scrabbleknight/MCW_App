// GENERATED from ViralEngine/funnel-kit/functions/commerce/index.js — edit it there and run `npm run funnel:sync`.
const fs = require('node:fs');
const path = require('node:path');

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const {
  Environment,
  SignedDataVerifier,
  VerificationException,
  VerificationStatus,
} = require('@apple/app-store-server-library');
const { androidpublisher, auth } = require('@googleapis/androidpublisher');

const {
  IOS_BUNDLE_ID,
  IOS_APP_APPLE_ID,
  ANDROID_PACKAGE,
  REGION,
} = require('../referrals/config');
const logic = require('./logic');

/**
 * Commerce ledger: the authoritative record of trials, purchases and
 * subscription lifecycle for the funnel (spec: ViralEngine/funnel-kit).
 *
 *   verifyStorePurchase   callable — the app hands over every purchase the
 *                         store reports; it's verified with Apple/Google and
 *                         recorded once per store transaction id
 *   appStoreNotifications HTTPS — App Store Server Notifications v2
 *                         (renewals, cancellations, expiries, refunds)
 *
 * Android renewals, cancellations and expiries come from Play's real-time
 * notifications, which Post-Bridge already pulls for every app.
 *
 * Firestore (server-only; no client rule matches these collections):
 *   commerceEvents/{key}       one per store transaction (ios_tx_…,
 *                              android_tx_…) or lifecycle notification
 *                              (ios_n_…). Never deleted.
 *   storeNotifications/{uuid}  every verified Apple notification, decoded
 *
 * No user id, name or email is stored. appInstanceId (Firebase's anonymous
 * analytics id) is only present when the user allowed analytics.
 *
 * Sandbox and license-tester purchases are recorded with
 * environment: 'sandbox' so testing works; reports leave them out.
 */

const db = () => getFirestore();
const ledger = () => db().collection('commerceEvents');

// ---------------------------------------------------------------- Apple ---

let appleRoots;
const appleVerifiers = {};

function appleVerifier(environment) {
  if (!appleVerifiers[environment]) {
    appleRoots ??= fs
      .readdirSync(path.join(__dirname, '..', 'certs'))
      .filter((n) => n.endsWith('.cer'))
      .map((n) => fs.readFileSync(path.join(__dirname, '..', 'certs', n)));
    appleVerifiers[environment] = new SignedDataVerifier(
      appleRoots,
      true,
      environment,
      IOS_BUNDLE_ID,
      environment === Environment.PRODUCTION ? IOS_APP_APPLE_ID : undefined,
    );
  }
  return appleVerifiers[environment];
}

/** Verifies with production first, then sandbox. Returns [payload, env]. */
async function appleVerify(method, signed) {
  try {
    return [await appleVerifier(Environment.PRODUCTION)[method](signed), 'production'];
  } catch (error) {
    const wrongEnv =
      error instanceof VerificationException &&
      error.status === VerificationStatus.INVALID_ENVIRONMENT;
    if (!wrongEnv) throw error;
    return [await appleVerifier(Environment.SANDBOX)[method](signed), 'sandbox'];
  }
}

// --------------------------------------------------------- Google Play ---

let play;
function playClient() {
  play ??= androidpublisher({
    version: 'v3',
    auth: new auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    }),
  });
  return play;
}

async function verifyPlay(productId, token) {
  try {
    const { data } = await playClient().purchases.subscriptionsv2.get({
      packageName: ANDROID_PACKAGE,
      token,
    });
    const item = data.lineItems?.[0] ?? {};
    return {
      productId: item.productId ?? productId,
      transactionId: item.latestSuccessfulOrderId || data.latestOrderId || null,
      storeTime: data.startTime ? new Date(data.startTime) : new Date(),
      environment: data.testPurchase ? 'sandbox' : 'production',
      classified: logic.classifyPlay(data),
    };
  } catch (error) {
    const status = error?.response?.status ?? error?.code;
    if (status !== 400 && status !== 404 && status !== 410) throw error;
  }
  // Not a subscription: a one-time product.
  try {
    const { data } = await playClient().purchases.products.get({
      packageName: ANDROID_PACKAGE,
      productId,
      token,
    });
    if (data.purchaseState !== 0) return null; // cancelled or pending
    return {
      productId,
      transactionId: data.orderId ?? null,
      storeTime: data.purchaseTimeMillis ? new Date(Number(data.purchaseTimeMillis)) : new Date(),
      environment: data.purchaseType === 0 ? 'sandbox' : 'production',
      classified: {
        event: logic.EVENTS.purchaseVerified,
        offer: 'none',
        paid: data.purchaseType !== 0,
        value: null,
        currency: null,
        reason: 'purchase',
        priorUnknown: false,
      },
    };
  } catch (error) {
    const status = error?.response?.status ?? error?.code;
    if (status === 400 || status === 404 || status === 410) return null;
    throw error;
  }
}

// --------------------------------------------------------------- ledger ---

async function entriesFor(originalId) {
  const snap = await ledger().where('originalId', '==', originalId).get();
  return snap.docs.map((d) => {
    const v = d.data();
    return { id: d.id, ...v, storeTime: v.storeTime?.toDate?.() ?? null };
  });
}

/**
 * Records a store transaction once. Returns whether this [source] is seeing
 * it for the first time (so the app logs an acquisition exactly once).
 */
async function recordTransaction(key, entry, source, extra = {}) {
  const ref = ledger().doc(key);
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Timestamp.now();
    if (!snap.exists) {
      tx.create(ref, {
        ...entry,
        ...extra,
        storeTime: Timestamp.fromDate(entry.storeTime),
        seenBy: { [source]: now },
        createdAt: FieldValue.serverTimestamp(),
      });
      return true;
    }
    const data = snap.data();
    const update = { [`seenBy.${source}`]: data.seenBy?.[source] ?? now };
    for (const [k, v] of Object.entries(extra)) {
      if (v != null && data[k] == null) update[k] = v;
    }
    tx.update(ref, update);
    return data.seenBy?.[source] == null;
  });
}

const cleanString = (v, max) =>
  typeof v === 'string' && v.length > 0 && v.length <= max ? v : null;

// ------------------------------------------------- verifyStorePurchase ---

exports.verifyStorePurchase = onCall({ region: REGION }, async (request) => {
  const data = request.data ?? {};
  const platform = data.platform;
  if (platform !== 'ios' && platform !== 'android') {
    throw new HttpsError('invalid-argument', 'platform must be ios or android.');
  }
  const verificationData = cleanString(data.verificationData, 20000);
  const productId = cleanString(data.productId, 200);
  if (!verificationData || !productId) {
    throw new HttpsError('invalid-argument', 'productId and verificationData are required.');
  }
  const restored = data.status === 'restored';
  const source = restored ? 'app_restore' : 'app_purchase';
  const extra = {
    appInstanceId: cleanString(data.appInstanceId, 64),
    placement: cleanString(data.placement, 40),
    // The social post behind the install (Play referrer), as the app read it.
    postCode: /^[tify][a-z0-9]{6}$/.test(String(data.postCode || '')) ? data.postCode : null,
  };

  let entry;
  if (platform === 'ios') {
    let tx;
    let environment;
    try {
      [tx, environment] = await appleVerify('verifyAndDecodeTransaction', verificationData);
    } catch (error) {
      logger.warn('Untrusted Apple purchase', { reason: String(error?.status ?? error?.message) });
      throw new HttpsError('permission-denied', 'Purchase not verified.');
    }
    if (tx.revocationDate) {
      throw new HttpsError('permission-denied', 'The purchase was refunded.');
    }
    const key = logic.transactionKey('ios', tx.transactionId);
    const storeTime = new Date(tx.purchaseDate ?? Date.now());
    const previous =
      tx.transactionReason === 'RENEWAL'
        ? logic.latestBefore(await entriesFor(String(tx.originalTransactionId)), storeTime, key)
        : null;
    const c = logic.classifyApple(tx, previous);
    entry = {
      key,
      platform,
      productId: tx.productId,
      transactionId: String(tx.transactionId),
      originalId: String(tx.originalTransactionId),
      storeTime,
      environment,
      ...c,
    };
  } else {
    const v = await verifyPlay(productId, verificationData);
    if (!v) throw new HttpsError('permission-denied', 'Purchase not verified.');
    const originalId = `tok_${logic.tokenHash(verificationData)}`;
    const transactionId = v.transactionId ?? originalId;
    entry = {
      key: logic.transactionKey('android', transactionId),
      platform,
      productId: v.productId,
      transactionId,
      originalId,
      storeTime: v.storeTime,
      environment: v.environment,
      ...v.classified,
    };
  }

  const { key, ...fields } = entry;
  const isNew = await recordTransaction(key, fields, source, extra);
  return {
    verified: true,
    // A restore is never an acquisition, whatever the ledger knew.
    event: restored ? null : entry.event,
    isNew,
    transactionId: entry.transactionId,
    productId: entry.productId,
    offer: entry.offer,
    paid: entry.paid,
    value: entry.value,
    currency: entry.currency,
    environment: entry.environment,
  };
});

// ----------------------------------------------- appStoreNotifications ---

/**
 * App Store Connect → App Information → App Store Server Notifications
 * (Version 2), production and sandbox URLs both pointing here.
 */
exports.appStoreNotifications = onRequest({ region: REGION }, async (req, res) => {
  if (req.method !== 'POST' || typeof req.body?.signedPayload !== 'string') {
    res.status(400).send('Expected a signedPayload.');
    return;
  }
  let note;
  let environment;
  try {
    [note, environment] = await appleVerify('verifyAndDecodeNotification', req.body.signedPayload);
  } catch (error) {
    logger.warn('Unverified App Store notification', { reason: String(error?.status ?? error?.message) });
    res.status(401).send('Not verified.');
    return;
  }

  const uuid = note.notificationUUID;
  const tx = note.data?.signedTransactionInfo
    ? (await appleVerify('verifyAndDecodeTransaction', note.data.signedTransactionInfo))[0]
    : null;
  const renewal = note.data?.signedRenewalInfo
    ? (await appleVerify('verifyAndDecodeRenewalInfo', note.data.signedRenewalInfo))[0]
    : null;

  try {
    await db().collection('storeNotifications').doc(uuid).create({
      notificationType: note.notificationType,
      subtype: note.subtype ?? null,
      environment,
      signedDate: note.signedDate ? Timestamp.fromMillis(note.signedDate) : null,
      transaction: tx && {
        transactionId: String(tx.transactionId),
        originalTransactionId: String(tx.originalTransactionId),
        productId: tx.productId,
        purchaseDate: tx.purchaseDate ?? null,
        expiresDate: tx.expiresDate ?? null,
        offerType: tx.offerType ?? null,
        offerDiscountType: tx.offerDiscountType ?? null,
        price: tx.price ?? null,
        currency: tx.currency ?? null,
        transactionReason: tx.transactionReason ?? null,
        storefront: tx.storefront ?? null,
      },
      renewal: renewal && {
        autoRenewStatus: renewal.autoRenewStatus ?? null,
        autoRenewProductId: renewal.autoRenewProductId ?? null,
        expirationIntent: renewal.expirationIntent ?? null,
      },
      receivedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (error?.code === 6) {
      // ALREADY_EXISTS: Apple retried one we've handled.
      res.status(200).send('ok');
      return;
    }
    throw error;
  }

  const meaning = logic.appleNotification(note.notificationType, note.subtype);
  if (meaning && tx) {
    const originalId = String(tx.originalTransactionId);
    const entries = await entriesFor(originalId);
    const appInstanceId = entries.find((e) => e.appInstanceId)?.appInstanceId ?? null;
    if (meaning.keyed === 'transaction') {
      const key = logic.transactionKey('ios', tx.transactionId);
      const storeTime = new Date(tx.purchaseDate ?? note.signedDate ?? Date.now());
      const c = logic.classifyApple(tx, logic.latestBefore(entries, storeTime, key));
      await recordTransaction(
        key,
        {
          platform: 'ios',
          productId: tx.productId,
          transactionId: String(tx.transactionId),
          originalId,
          storeTime,
          environment,
          ...c,
          notificationReason: meaning.reason,
        },
        'notification',
        { appInstanceId },
      );
    } else {
      await recordTransaction(
        `ios_n_${uuid}`,
        {
          platform: 'ios',
          productId: tx.productId,
          transactionId: String(tx.transactionId),
          originalId,
          storeTime: new Date(note.signedDate ?? Date.now()),
          environment,
          event: meaning.event,
          reason: meaning.reason,
        },
        'notification',
        { appInstanceId },
      );
      if (meaning.event === logic.EVENTS.refunded) {
        const ref = ledger().doc(logic.transactionKey('ios', tx.transactionId));
        await ref.update({ refunded: true }).catch(() => {}); // unknown purchase: nothing to mark
      }
    }
  }
  res.status(200).send('ok');
});

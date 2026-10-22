const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const {
  Environment,
  PromotionalOfferSignatureCreator,
  SignedDataVerifier,
  VerificationException,
  VerificationStatus,
} = require('@apple/app-store-server-library');
const { androidpublisher, auth } = require('@googleapis/androidpublisher');

const {
  IOS_BUNDLE_ID,
  IOS_APP_APPLE_ID,
  ANDROID_PACKAGE,
} = require('./config');

/**
 * Thrown when a purchase the app reported isn't one the store vouches for:
 * a bad signature, another app's purchase, or a test purchase while those
 * are switched off.
 */
class UntrustedPurchase extends Error {}

// ---------------------------------------------------------------- Apple ---

let appleRoots;

/**
 * Apple's root certificates (functions/certs/*.cer, from
 * https://www.apple.com/certificateauthority/). A transaction only verifies
 * if its signing chain ends at one of these.
 */
function appleRootCertificates() {
  if (!appleRoots) {
    const dir = path.join(__dirname, '..', 'certs');
    appleRoots = fs
      .readdirSync(dir)
      .filter((name) => name.endsWith('.cer'))
      .map((name) => fs.readFileSync(path.join(dir, name)));
    if (appleRoots.length === 0) {
      throw new Error('No Apple root certificates in functions/certs.');
    }
  }
  return appleRoots;
}

const appleVerifiers = {};

function appleVerifier(environment) {
  if (!appleVerifiers[environment]) {
    appleVerifiers[environment] = new SignedDataVerifier(
      appleRootCertificates(),
      true,
      environment,
      IOS_BUNDLE_ID,
      // Apple only checks the app id in production; sandbox transactions
      // don't carry it.
      environment === Environment.PRODUCTION ? IOS_APP_APPLE_ID : undefined,
    );
  }
  return appleVerifiers[environment];
}

/**
 * Checks a StoreKit 2 transaction's JWS (what the app gets as
 * `serverVerificationData`) and returns the fields the referral logic uses.
 * Sandbox transactions (Xcode, TestFlight) are free to make, so they're only
 * trusted when [allowSandbox] is on.
 */
async function verifyAppleTransaction(jws, { allowSandbox }) {
  let payload;
  try {
    payload = await appleVerifier(Environment.PRODUCTION)
      .verifyAndDecodeTransaction(jws);
  } catch (error) {
    const wrongEnvironment =
      error instanceof VerificationException &&
      error.status === VerificationStatus.INVALID_ENVIRONMENT;
    if (!wrongEnvironment) throw new UntrustedPurchase(describe(error));
    if (!allowSandbox) {
      throw new UntrustedPurchase('Sandbox purchases are switched off.');
    }
    try {
      payload = await appleVerifier(Environment.SANDBOX)
        .verifyAndDecodeTransaction(jws);
    } catch (sandboxError) {
      throw new UntrustedPurchase(describe(sandboxError));
    }
  }
  if (payload.revocationDate) {
    throw new UntrustedPurchase('The purchase was refunded.');
  }
  return {
    productId: payload.productId,
    originalTransactionId: payload.originalTransactionId,
    transactionId: payload.transactionId,
    offerType: payload.offerType ?? null,
    offerIdentifier: payload.offerIdentifier ?? null,
  };
}

function describe(error) {
  if (error instanceof VerificationException) {
    return `Apple verification failed (status ${error.status}).`;
  }
  return String(error?.message ?? error);
}

let promoSigner;

/**
 * Signs an Apple promotional offer so StoreKit will apply it. Uses the
 * In-App Purchase key from App Store Connect (Users and Access →
 * Integrations → In-App Purchase), stored as the APPLE_IAP_KEY and
 * APPLE_IAP_KEY_ID secrets.
 */
function signPromotionalOffer({ productId, offerId, privateKey, keyId }) {
  if (!promoSigner) {
    promoSigner = new PromotionalOfferSignatureCreator(
      privateKey,
      keyId,
      IOS_BUNDLE_ID,
    );
  }
  const nonce = crypto.randomUUID();
  const timestamp = Date.now();
  // The app buys without an appAccountToken, so the signature is made with
  // an empty one.
  const signature = promoSigner.createSignature(
    productId,
    offerId,
    '',
    nonce,
    timestamp,
  );
  return { productId, offerId, keyId, nonce, timestamp, signature };
}

// --------------------------------------------------------- Google Play ---

let play;

/**
 * Android Publisher client running as the functions' service account, which
 * needs access to the app in Play Console (Users and permissions).
 */
function playClient() {
  if (!play) {
    play = androidpublisher({
      version: 'v3',
      auth: new auth.GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
      }),
    });
  }
  return play;
}

/**
 * Looks a Play subscription up by its purchase token (what the app gets as
 * `serverVerificationData`) and returns the fields the referral logic uses.
 * License-tester purchases cost nothing, so they're only trusted when
 * [allowTest] is on.
 */
async function verifyPlaySubscription(purchaseToken, { allowTest }) {
  let data;
  try {
    ({ data } = await playClient().purchases.subscriptionsv2.get({
      packageName: ANDROID_PACKAGE,
      token: purchaseToken,
    }));
  } catch (error) {
    const status = error?.response?.status ?? error?.code;
    if (status === 400 || status === 404 || status === 410) {
      throw new UntrustedPurchase(`Play doesn't know this purchase (${status}).`);
    }
    throw error;
  }
  if (data.testPurchase && !allowTest) {
    throw new UntrustedPurchase('Test purchases are switched off.');
  }
  const item = data.lineItems?.[0] ?? {};
  return {
    purchaseToken,
    productId: item.productId ?? null,
    basePlanId: item.offerDetails?.basePlanId ?? null,
    offerId: item.offerDetails?.offerId ?? null,
    state: data.subscriptionState ?? null,
    etag: data.etag ?? null,
  };
}

/** Pushes a Play subscription's next renewal back by [days]. */
async function deferPlaySubscription({ purchaseToken, etag, days }) {
  const { data } = await playClient().purchases.subscriptionsv2.defer({
    packageName: ANDROID_PACKAGE,
    token: purchaseToken,
    requestBody: {
      deferralContext: { etag, deferDuration: `${days * 24 * 60 * 60}s` },
    },
  });
  return data.itemExpiryTimeDetails?.[0]?.expiryTime ?? null;
}

module.exports = {
  UntrustedPurchase,
  verifyAppleTransaction,
  signPromotionalOffer,
  verifyPlaySubscription,
  deferPlaySubscription,
};

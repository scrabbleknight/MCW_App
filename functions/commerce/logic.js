// GENERATED from ViralEngine/funnel-kit/functions/commerce/logic.js — edit it there and run `npm run funnel:sync`.
/**
 * Pure rules for the commerce ledger: what a store transaction or
 * notification means for the funnel. No I/O, so they're unit-tested
 * (test/commerce.test.js).
 *
 * Event names match the app-side funnel (funnel_tracker.dart, spec in
 * ViralEngine/funnel-kit/README.md).
 */

const crypto = require('node:crypto');

const EVENTS = {
  trialStart: 'trial_start',
  purchaseVerified: 'purchase_verified',
  trialConverted: 'trial_converted_to_paid',
  renewed: 'subscription_renewed',
  cancelled: 'subscription_cancelled',
  expired: 'subscription_expired',
  refunded: 'purchase_refunded',
};

/** Same 24-character hash Post-Bridge uses for Play purchase tokens. */
const tokenHash = (t) =>
  crypto.createHash('sha256').update(String(t)).digest('hex').slice(0, 24);

/**
 * Apple offer types: 1 introductory (free trial or intro price), 2
 * promotional, 3 offer code. Apple prices are in milliunits.
 */
function appleOffer(tx) {
  if (tx.offerType === 1) {
    return tx.offerDiscountType === 'FREE_TRIAL' || tx.price === 0 ? 'trial' : 'intro';
  }
  if (tx.offerType === 2) return 'promo';
  if (tx.offerType === 3) return 'offer_code';
  return 'none';
}

/**
 * What an Apple transaction is. [previous] is the latest earlier ledger
 * entry for the same subscription (same originalTransactionId), used to
 * tell a trial's first paid renewal from an ordinary one.
 */
function classifyApple(tx, previous = null) {
  const offer = appleOffer(tx);
  const price = typeof tx.price === 'number' ? tx.price : null;
  const paid = offer !== 'trial' && (price == null ? offer === 'none' : price > 0);
  const renewal = tx.transactionReason === 'RENEWAL';
  let event;
  if (renewal) {
    event =
      previous && previous.offer === 'trial' && !previous.paid
        ? EVENTS.trialConverted
        : EVENTS.renewed;
  } else {
    event = offer === 'trial' ? EVENTS.trialStart : EVENTS.purchaseVerified;
  }
  return {
    event,
    offer,
    paid,
    value: paid && price != null ? Math.round(price) / 1000 : null,
    currency: tx.currency ?? null,
    reason: renewal ? 'renewal' : 'purchase',
    priorUnknown: renewal && !previous,
  };
}

/** Which pricing phase a Play subscription line item is in. */
function playOffer(item) {
  const phase = item?.offerPhase ?? {};
  if (phase.freeTrial) return 'trial';
  if (phase.introductoryPrice) return 'intro';
  if (phase.basePrice || phase.prorationPeriod) return 'none';
  return item?.offerDetails?.offerId ? 'unknown_offer' : 'none';
}

/** A Play subscription the app reported (purchases.subscriptionsv2.get). */
function classifyPlay(data) {
  const item = data.lineItems?.[0] ?? {};
  const offer = playOffer(item);
  const paid = offer !== 'trial';
  return {
    event: offer === 'trial' ? EVENTS.trialStart : EVENTS.purchaseVerified,
    offer,
    paid,
    value: null, // Play's subscription API has no price; revenue comes from Play reports
    currency: null,
    reason: 'purchase',
    priorUnknown: false,
  };
}

/** The ledger id for a store transaction: dedupes every report of it. */
function transactionKey(platform, transactionId) {
  return `${platform}_tx_${String(transactionId).replace(/[^A-Za-z0-9._-]/g, '_')}`;
}

/**
 * The funnel event an App Store Server Notification (v2) stands for, if
 * any: { event, keyed: 'transaction' | 'notification', reason }.
 * SUBSCRIBED and DID_RENEW carry a new transaction (classified with
 * classifyApple); the rest are keyed by the notification's UUID.
 */
function appleNotification(type, subtype) {
  switch (type) {
    case 'SUBSCRIBED':
      return { event: null, keyed: 'transaction', reason: subtype ?? null };
    case 'DID_RENEW':
      return { event: null, keyed: 'transaction', reason: subtype ?? null };
    case 'DID_CHANGE_RENEWAL_STATUS':
      return subtype === 'AUTO_RENEW_DISABLED'
        ? { event: EVENTS.cancelled, keyed: 'notification', reason: null }
        : null;
    case 'EXPIRED':
      return { event: EVENTS.expired, keyed: 'notification', reason: subtype ?? null };
    case 'GRACE_PERIOD_EXPIRED':
      return { event: EVENTS.expired, keyed: 'notification', reason: 'BILLING_GRACE_PERIOD' };
    case 'REFUND':
      return { event: EVENTS.refunded, keyed: 'notification', reason: null };
    default:
      return null;
  }
}

/** The latest ledger entry before [at] among [entries] (same subscription). */
function latestBefore(entries, at, excludeId) {
  let best = null;
  for (const e of entries) {
    if (e.id === excludeId || !e.storeTime) continue;
    if (at && e.storeTime >= at) continue;
    if (!best || e.storeTime > best.storeTime) best = e;
  }
  return best;
}

module.exports = {
  EVENTS,
  tokenHash,
  appleOffer,
  classifyApple,
  playOffer,
  classifyPlay,
  transactionKey,
  appleNotification,
  latestBefore,
};

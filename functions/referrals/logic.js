const crypto = require('node:crypto');

const {
  TIERS,
  SUBSCRIPTIONS,
  FRIEND_OFFER,
  IOS_PROMO_OFFERS,
  IOS_APP_APPLE_ID,
} = require('./config');

/** No 0/O, 1/I/L: codes get read aloud and typed from screenshots. */
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;

function generateCode(randomBytes = crypto.randomBytes) {
  const bytes = randomBytes(CODE_LENGTH);
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  return code;
}

/**
 * Upper-cases a typed code and drops spaces and dashes. Null if what's left
 * can't be a referral code.
 */
function normalizeCode(input) {
  if (typeof input !== 'string') return null;
  const code = input.toUpperCase().replace(/[\s-]/g, '');
  if (code.length !== CODE_LENGTH) return null;
  for (const ch of code) {
    if (!CODE_ALPHABET.includes(ch)) return null;
  }
  return code;
}

/**
 * 'monthly', 'yearly' or (retired) 'weekly' for a standard or friend
 * subscription, else null.
 */
function planForProduct(platform, productId) {
  for (const products of [SUBSCRIPTIONS[platform], FRIEND_OFFER[platform]]) {
    if (!products) continue;
    for (const [plan, id] of Object.entries(products)) {
      if (id === productId) return plan;
    }
  }
  return null;
}

/**
 * Whether a verified purchase is a friend buying with a referral discount.
 * `purchase` is what stores.js returns: productId, plus offerType (Apple) or
 * offerId (Play).
 */
function isFriendPurchase(platform, purchase) {
  if (platform === 'ios') {
    // 1 = introductory offer. The friend twin's only intro offer is the
    // referral discount.
    return (
      Object.values(FRIEND_OFFER.ios).includes(purchase.productId) &&
      purchase.offerType === 1
    );
  }
  return purchase.offerId === FRIEND_OFFER.androidOfferId;
}

/** The reward an Apple promotional offer identifier delivers, if any. */
function rewardForPromoOffer(offerIdentifier) {
  for (const [reward, offers] of Object.entries(IOS_PROMO_OFFERS)) {
    if (Object.values(offers).some((o) => o.offerId === offerIdentifier)) {
      return reward;
    }
  }
  return null;
}

/** Rewards a referrer with [count] subscribed friends has earned. */
function rewardsEarned(count) {
  return TIERS.filter((tier) => count >= tier.friends).map((t) => t.reward);
}

/** Where a single-use Lifetime code is redeemed in each store. */
function redeemUrl(platform, code) {
  const encoded = encodeURIComponent(code);
  return platform === 'ios'
    ? `https://apps.apple.com/redeem?ctx=offercodes&id=${IOS_APP_APPLE_ID}&code=${encoded}`
    : `https://play.google.com/redeem?code=${encoded}`;
}

/**
 * Document id for a store purchase, so one purchase can only ever qualify one
 * referral. Play tokens are long and can contain characters Firestore ids
 * can't, so they're hashed.
 */
function purchaseKey(platform, purchase) {
  if (platform === 'ios') return `ios_${purchase.originalTransactionId}`;
  const hash = crypto
    .createHash('sha256')
    .update(purchase.purchaseToken)
    .digest('hex');
  return `android_${hash}`;
}

module.exports = {
  CODE_ALPHABET,
  generateCode,
  normalizeCode,
  planForProduct,
  isFriendPurchase,
  rewardForPromoOffer,
  rewardsEarned,
  redeemUrl,
  purchaseKey,
};

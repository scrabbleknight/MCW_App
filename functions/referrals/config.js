/**
 * Everything the referral backend needs to match in App Store Connect and
 * Play Console. Change a value here only together with the store.
 */

const IOS_BUNDLE_ID = 'com.swiftbee.militaryCalisthenicsWomen';
const IOS_APP_APPLE_ID = 6809903076;
const ANDROID_PACKAGE = 'com.swiftbee.military_calisthenics_women';

/**
 * Referral rewards, in the order a referrer earns them. `friends` is how many
 * friends must have subscribed with the referrer's code.
 */
const TIERS = [
  { reward: 'half_1y', friends: 1 },
  { reward: 'free_1y', friends: 2 },
  { reward: 'lifetime', friends: 3 },
];

/**
 * A friend's purchase stays pending this long before it counts towards the
 * referrer's rewards, and is dropped if it's refunded in that time. Apple and
 * Google refund most requests within days, so without it a friend could buy,
 * earn the referrer a reward, then get their money back.
 */
const REFERRAL_HOLD_DAYS = 14;

/** The standard subscriptions, keyed by plan, per store. */
const SUBSCRIPTIONS = {
  ios: {
    weekly: 'com.swiftbee.militarycalisthenicswomen.weekly',
    yearly: 'com.swiftbee.militarycalisthenicswomen.annual',
  },
  android: {
    weekly: 'com.swiftbee.militarycalisthenics.weekly',
    yearly: 'com.swiftbee.militarycalisthenics.annual',
  },
};

/**
 * The friend's discount: 50% off the first year of Annual. Weekly has no
 * friend discount (Apple caps weekly intro discounts at 12 weeks).
 *
 * iOS: Apple only gives introductory offers to new subscribers, and
 * promotional offers only to existing ones, so the friend buys a twin of
 * Annual (same subscription group) whose introductory offer is the discount.
 * The app offers these only after the server accepts a code.
 *
 * Android: a developer-determined offer on the annual base plan. Play
 * shows it to nobody unless the app asks for it.
 */
const FRIEND_OFFER = {
  ios: {
    yearly: 'com.swiftbee.militarycalisthenicswomen.annual.friend',
  },
  androidOfferId: 'referral-friend',
};

/**
 * iOS promotional offers that deliver the referrer's subscription rewards:
 * for each reward and the plan the referrer is on, the standard plan to buy
 * and the offer to buy it with. A referrer on the friend twin moves to the
 * standard Annual. Half price for a year is always a year of Annual, so a
 * Weekly subscriber claiming it upgrades to Annual at half price.
 */
const IOS_PROMO_OFFERS = {
  half_1y: {
    weekly: { plan: 'yearly', offerId: 'ref_half1y_annual' },
    yearly: { plan: 'yearly', offerId: 'ref_half1y_annual' },
  },
  free_1y: {
    weekly: { plan: 'weekly', offerId: 'ref_free1y_weekly' },
    yearly: { plan: 'yearly', offerId: 'ref_free1y_annual' },
  },
};

/**
 * Play has no discount for someone who is already subscribed, so Android
 * rewards push the next renewal back instead. Half price for a year is worth
 * about half a year free.
 */
const ANDROID_DEFER_DAYS = { half_1y: 182, free_1y: 365 };

/**
 * Rewards that only apply after the user has kept paying this long: half
 * price for a year is "pay for 182 days, get the next 182 free", so claiming
 * it schedules the free days rather than giving them up front (which a user
 * could take and then cancel).
 */
const ANDROID_DEFER_AFTER_DAYS = { half_1y: 182 };

/**
 * Free for life: a one-time "Lifetime" product, given away with single-use
 * codes from a pool loaded by scripts/load-reward-codes.js.
 */
const LIFETIME = {
  ios: 'com.swiftbee.militarycalisthenicswomen.lifetime',
  // Play caps product IDs at 40 characters, so not "…lifetime".
  android: 'com.swiftbee.militarycalisthenics.life',
};

const REGION = 'europe-west2';

module.exports = {
  IOS_BUNDLE_ID,
  IOS_APP_APPLE_ID,
  ANDROID_PACKAGE,
  TIERS,
  REFERRAL_HOLD_DAYS,
  SUBSCRIPTIONS,
  FRIEND_OFFER,
  IOS_PROMO_OFFERS,
  ANDROID_DEFER_DAYS,
  ANDROID_DEFER_AFTER_DAYS,
  LIFETIME,
  REGION,
};

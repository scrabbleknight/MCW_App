const test = require('node:test');
const assert = require('node:assert/strict');

const logic = require('../referrals/logic');
const { _test } = require('../referrals');

test('codes use the unambiguous alphabet and round-trip', () => {
  for (let i = 0; i < 200; i++) {
    const code = logic.generateCode();
    assert.equal(code.length, 6);
    assert.equal(logic.normalizeCode(code), code);
  }
});

test('typed codes are tidied, and impossible ones rejected', () => {
  assert.equal(logic.normalizeCode(' abc-d23 '), 'ABCD23');
  assert.equal(logic.normalizeCode('ABC D23'), 'ABCD23');
  assert.equal(logic.normalizeCode('ABCD2O'), null); // letter O
  assert.equal(logic.normalizeCode('ABC'), null);
  assert.equal(logic.normalizeCode(42), null);
});

test('rewards unlock at 1, 2 and 3 friends', () => {
  assert.deepEqual(logic.rewardsEarned(0), []);
  assert.deepEqual(logic.rewardsEarned(1), ['half_1y']);
  assert.deepEqual(logic.rewardsEarned(2), ['half_1y', 'free_1y']);
  assert.deepEqual(logic.rewardsEarned(3), ['half_1y', 'free_1y', 'lifetime']);
  assert.deepEqual(logic.rewardsEarned(9), ['half_1y', 'free_1y', 'lifetime']);
});

test('only the friend discount counts as a friend purchase', () => {
  const friendIos = {
    productId: 'com.swiftbee.militarycalisthenicswomen.annual.friend',
    offerType: 1,
  };
  assert.equal(logic.isFriendPurchase('ios', friendIos), true);
  assert.equal(
    logic.isFriendPurchase('ios', { ...friendIos, offerType: null }),
    false,
  );
  assert.equal(
    logic.isFriendPurchase('ios', {
      productId: 'com.swiftbee.militarycalisthenicswomen.annual',
      offerType: 1, // the normal free trial
    }),
    false,
  );
  assert.equal(
    logic.isFriendPurchase('android', { offerId: 'referral-friend' }),
    true,
  );
  assert.equal(
    logic.isFriendPurchase('android', { offerId: 'free-trial-3-day' }),
    false,
  );
});

test('plans are found for standard and friend products', () => {
  assert.equal(logic.planForProduct('ios', 'com.swiftbee.militarycalisthenicswomen.weekly'), 'weekly');
  assert.equal(logic.planForProduct('ios', 'com.swiftbee.militarycalisthenicswomen.annual.friend'), 'yearly');
  assert.equal(logic.planForProduct('android', 'com.swiftbee.militarycalisthenics.annual'), 'yearly');
  assert.equal(logic.planForProduct('android', 'com.swiftbee.militarycalisthenicswomen.annual'), null);
});

test('promotional offer ids map back to their reward', () => {
  assert.equal(logic.rewardForPromoOffer('ref_half1y_annual'), 'half_1y');
  assert.equal(logic.rewardForPromoOffer('ref_free1y_weekly'), 'free_1y');
  assert.equal(logic.rewardForPromoOffer('something_else'), null);
});

test('purchase keys are stable and Firestore-safe', () => {
  const key = logic.purchaseKey('android', { purchaseToken: 'a/b.c' });
  assert.match(key, /^android_[0-9a-f]{64}$/);
  assert.equal(key, logic.purchaseKey('android', { purchaseToken: 'a/b.c' }));
  assert.equal(
    logic.purchaseKey('ios', { originalTransactionId: '2000001' }),
    'ios_2000001',
  );
});

test('status only shows a Lifetime code on the platform it was issued for', () => {
  const data = {
    code: 'ABCD23',
    friends: 3,
    rewards: {
      half_1y: { state: 'redeemed' },
      free_1y: { state: 'earned' },
      lifetime: { state: 'codeIssued', code: 'XYZ', platform: 'ios' },
    },
    referredBy: { code: 'QWERTY' },
  };
  const ios = _test.statusOf(data, 'ios');
  assert.deepEqual(
    ios.tiers.map((t) => t.state),
    ['redeemed', 'earned', 'codeIssued'],
  );
  assert.equal(ios.tiers[2].code, 'XYZ');
  assert.match(ios.tiers[2].redeemUrl, /apps\.apple\.com\/redeem.*code=XYZ/);
  assert.equal(_test.statusOf(data, 'android').tiers[2].code, undefined);
  assert.deepEqual(ios.friendDiscount, { code: 'QWERTY', state: 'available' });
});

test('applyDotted leaves the original alone', () => {
  const data = { rewards: { a: { state: 'earned' } } };
  const out = _test.applyDotted(data, { 'rewards.a.state': 'redeemed' });
  assert.equal(out.rewards.a.state, 'redeemed');
  assert.equal(data.rewards.a.state, 'earned');
});

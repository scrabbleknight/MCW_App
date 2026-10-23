// End-to-end referral flow against the Firestore emulator, with the store
// checks stubbed. Run: npm run test:emulator
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT ??= 'demo-mcw';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const stores = require('../referrals/stores');
const referrals = require('../referrals');

const call = (fn, uid, data) => referrals[fn].run({ auth: { uid }, data });

async function rejects(promise, message) {
  await assert.rejects(promise, (e) => e.message === message);
}

let txn = 0;
stores.verifyAppleTransaction = async (jws) => ({
  ...JSON.parse(jws),
  originalTransactionId: String(++txn),
  transactionId: `t${txn}`,
});
const refunded = new Set();
stores.appleTransactionRefunded = async ({ transactionId }) =>
  refunded.has(transactionId);
stores.playVoidedTokens = async () => new Set();
stores.verifyPlaySubscription = async (token) => ({
  purchaseToken: token,
  productId: 'com.swiftbee.militarycalisthenics.annual',
  offerId: 'referral-friend',
  state: 'SUBSCRIPTION_STATE_ACTIVE',
  etag: 'e1',
});
const deferred = [];
stores.deferPlaySubscription = async (args) => {
  deferred.push(args);
  return '2027-12-01T00:00:00Z';
};

/** Ends every pending friend purchase's hold and runs the daily check. */
async function settle() {
  const pending = await getFirestore()
    .collection('referralPurchases')
    .where('state', '==', 'pending')
    .get();
  for (const doc of pending.docs) {
    await doc.ref.update({ confirmsAt: new Date(Date.now() - 1000) });
  }
  await referrals.confirmReferrals.run({});
}

const friendBuy = (uid) =>
  call('recordPurchase', uid, {
    platform: 'ios',
    verificationData: JSON.stringify({
      productId: 'com.swiftbee.militarycalisthenicswomen.annual.friend',
      offerType: 1,
    }),
  });

test('a referrer climbs the tiers as friends subscribe', async () => {
  const me = await call('referralStatus', 'referrer', { platform: 'android' });
  assert.equal(me.code.length, 6);
  assert.equal(me.friends, 0);

  await rejects(
    call('applyReferralCode', 'referrer', { platform: 'ios', code: me.code }),
    'own-code',
  );
  await rejects(
    call('applyReferralCode', 'f1', { platform: 'ios', code: 'ZZZZZZ' }),
    "That code doesn't exist.",
  );

  const applied = await call('applyReferralCode', 'f1', {
    platform: 'ios',
    code: me.code.toLowerCase(),
  });
  assert.deepEqual(applied.friendDiscount, { code: me.code, state: 'available' });

  // A normal purchase (the 3-day trial) doesn't count.
  await call('recordPurchase', 'f1', {
    platform: 'ios',
    verificationData: JSON.stringify({
      productId: 'com.swiftbee.militarycalisthenicswomen.annual',
      offerType: 1,
    }),
  });
  let status = await call('referralStatus', 'referrer', { platform: 'android' });
  assert.equal(status.friends, 0);

  const bought = await friendBuy('f1');
  assert.equal(bought.friendDiscount.state, 'used');
  // Reporting the same friend again doesn't double count.
  await friendBuy('f1');
  // Nothing counts until the 14-day hold is over.
  status = await call('referralStatus', 'referrer', { platform: 'android' });
  assert.equal(status.friends, 0);
  assert.equal(status.pendingFriends, 1);
  assert.deepEqual(status.tiers.map((t) => t.state), ['locked', 'locked', 'locked']);
  // Not due yet: still pending.
  await referrals.confirmReferrals.run({});
  status = await call('referralStatus', 'referrer', { platform: 'android' });
  assert.equal(status.pendingFriends, 1);

  await settle();
  status = await call('referralStatus', 'referrer', { platform: 'android' });
  assert.equal(status.friends, 1);
  assert.equal(status.pendingFriends, 0);
  assert.deepEqual(status.tiers.map((t) => t.state), ['earned', 'locked', 'locked']);

  // A friend can't switch to a second code.
  await call('referralStatus', 'other', { platform: 'ios' });
  const other = await call('referralStatus', 'other', { platform: 'ios' });
  await rejects(
    call('applyReferralCode', 'f1', { platform: 'ios', code: other.code }),
    'already-applied',
  );

  for (const f of ['f2', 'f3']) {
    await call('applyReferralCode', f, { platform: 'ios', code: me.code });
    await friendBuy(f);
  }
  await settle();
  status = await call('referralStatus', 'referrer', { platform: 'android' });
  assert.equal(status.friends, 3);
  assert.deepEqual(status.tiers.map((t) => t.state), ['earned', 'earned', 'earned']);
});

test('a friend refunded during the hold earns nothing', async () => {
  const me = await call('referralStatus', 'refunded-ref', { platform: 'ios' });
  await call('applyReferralCode', 'refunder', { platform: 'ios', code: me.code });
  await friendBuy('refunder');
  refunded.add(`t${txn}`);
  await settle();
  const status = await call('referralStatus', 'refunded-ref', { platform: 'ios' });
  assert.equal(status.friends, 0);
  assert.equal(status.pendingFriends, 0);
  assert.equal(status.tiers[0].state, 'locked');
  // The refunded purchase can't qualify again.
  await friendBuy('refunder');
  const after = await call('referralStatus', 'refunded-ref', { platform: 'ios' });
  assert.equal(after.pendingFriends, 0);
});

test('a refund check that fails waits for the next run', async () => {
  const me = await call('referralStatus', 'retry-ref', { platform: 'ios' });
  await call('applyReferralCode', 'retry-f', { platform: 'ios', code: me.code });
  await friendBuy('retry-f');
  const realCheck = stores.appleTransactionRefunded;
  stores.appleTransactionRefunded = async () => {
    throw new Error('App Store unavailable');
  };
  await settle();
  stores.appleTransactionRefunded = realCheck;
  let status = await call('referralStatus', 'retry-ref', { platform: 'ios' });
  assert.equal(status.pendingFriends, 1);
  await settle();
  status = await call('referralStatus', 'retry-ref', { platform: 'ios' });
  assert.equal(status.friends, 1);
  assert.equal(status.pendingFriends, 0);
});

test('Android half-price year is free only after 182 more paid days', async () => {
  const claim = await call('claimReferralReward', 'referrer', {
    platform: 'android',
    reward: 'half_1y',
    verificationData: 'token-1',
  });
  assert.equal(claim.kind, 'scheduled');
  assert.equal(deferred.length, 0);
  assert.equal(claim.status.tiers[0].state, 'scheduled');
  const days = (Date.parse(claim.appliesAt) - Date.now()) / 86400000;
  assert.ok(days > 181.9 && days < 182.1);
  await rejects(
    call('claimReferralReward', 'referrer', {
      platform: 'android',
      reward: 'half_1y',
      verificationData: 'token-1',
    }),
    'already-redeemed',
  );

  // Not due yet: nothing happens.
  await referrals.applyScheduledRewards.run({});
  assert.equal(deferred.length, 0);

  // 182 days later, still subscribed: the free days are added.
  const fs = getFirestore();
  await fs.doc('referralUsers/referrer').update({
    'rewards.half_1y.scheduledFor': new Date(Date.now() - 1000),
  });
  await referrals.applyScheduledRewards.run({});
  assert.equal(deferred.at(-1).days, 182);
  assert.equal(deferred.at(-1).purchaseToken, 'token-1');
  const after = await call('referralStatus', 'referrer', { platform: 'android' });
  assert.equal(after.tiers[0].state, 'redeemed');
});

test('a scheduled Android reward is kept back if the user cancelled', async () => {
  const me = await call('referralStatus', 'quitter', { platform: 'android' });
  await call('applyReferralCode', 'quitter-f', { platform: 'ios', code: me.code });
  await friendBuy('quitter-f');
  await settle();
  await call('claimReferralReward', 'quitter', {
    platform: 'android',
    reward: 'half_1y',
    verificationData: 'token-quit',
  });
  await getFirestore().doc('referralUsers/quitter').update({
    'rewards.half_1y.scheduledFor': new Date(Date.now() - 1000),
  });
  const realVerify = stores.verifyPlaySubscription;
  stores.verifyPlaySubscription = async (token) => ({
    ...(await realVerify(token)),
    state: 'SUBSCRIPTION_STATE_CANCELED',
  });
  const before = deferred.length;
  await referrals.applyScheduledRewards.run({});
  stores.verifyPlaySubscription = realVerify;
  assert.equal(deferred.length, before);
  const status = await call('referralStatus', 'quitter', { platform: 'android' });
  assert.equal(status.tiers[0].state, 'earned');
});

test('Android free year defers straight away', async () => {
  const claim = await call('claimReferralReward', 'referrer', {
    platform: 'android',
    reward: 'free_1y',
    verificationData: 'token-1',
  });
  assert.equal(claim.kind, 'deferred');
  assert.equal(deferred.at(-1).days, 365);
});

test('Lifetime hands out one pooled code and keeps it', async () => {
  const pool = getFirestore().collection('rewardCodes');
  await rejects(
    call('claimReferralReward', 'referrer', { platform: 'android', reward: 'lifetime' }),
    'no-codes',
  );
  const inMonths = (m) => new Date(Date.now() + m * 30 * 24 * 60 * 60 * 1000);
  // Too close to expiry to hand out.
  await pool.doc('android_OLD1').set({ platform: 'android', code: 'OLD1', assignedTo: null, expiresAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000) });
  await pool.doc('android_PLAY1').set({ platform: 'android', code: 'PLAY1', assignedTo: null, expiresAt: inMonths(5) });
  await pool.doc('android_PLAY2').set({ platform: 'android', code: 'PLAY2', assignedTo: null, expiresAt: inMonths(6) });

  const first = await call('claimReferralReward', 'referrer', {
    platform: 'android',
    reward: 'lifetime',
  });
  assert.equal(first.kind, 'code');
  // The soonest-expiring code that still has time left goes first.
  assert.equal(first.code, 'PLAY1');
  assert.match(first.redeemUrl, /play\.google\.com\/redeem\?code=PLAY/);
  const again = await call('claimReferralReward', 'referrer', {
    platform: 'android',
    reward: 'lifetime',
  });
  assert.equal(again.code, first.code);
  const assigned = await pool.where('assignedTo', '==', 'referrer').get();
  assert.equal(assigned.size, 1);

  const done = await call('recordPurchase', 'referrer', {
    platform: 'android',
    productId: 'com.swiftbee.militarycalisthenics.life',
    verificationData: 'lifetime-token',
  });
  assert.equal(done.tiers[2].state, 'redeemed');
});

test('an Apple promotional offer purchase marks its reward redeemed', async () => {
  const me = await call('referralStatus', 'apple-ref', { platform: 'ios' });
  await call('applyReferralCode', 'apple-f1', { platform: 'ios', code: me.code });
  await friendBuy('apple-f1');
  await settle();
  const out = await call('recordPurchase', 'apple-ref', {
    platform: 'ios',
    verificationData: JSON.stringify({
      productId: 'com.swiftbee.militarycalisthenicswomen.annual',
      offerType: 2,
      offerIdentifier: 'ref_half1y_annual',
    }),
  });
  assert.equal(out.tiers[0].state, 'redeemed');
});

test('deleting an account removes its code but keeps purchases spent', async () => {
  const me = await call('referralStatus', 'leaver', { platform: 'ios' });
  await call('applyReferralCode', 'leaver-f', { platform: 'ios', code: me.code });
  await friendBuy('leaver-f');
  await referrals.deleteReferralData('leaver-f');
  await referrals.deleteReferralData('leaver');

  const fs = getFirestore();
  assert.equal((await fs.doc('referralUsers/leaver').get()).exists, false);
  assert.equal((await fs.doc(`referralCodes/${me.code}`).get()).exists, false);
  const spent = await fs.collection('referralPurchases').where('uid', '==', 'leaver-f').get();
  assert.equal(spent.size, 0);
  const anonymised = await fs.collection('referralPurchases').where('uid', '==', null).get();
  assert.equal(anonymised.size, 1);
});

test('an issued Lifetime code that expired unredeemed is replaced', async () => {
  const fs = getFirestore();
  const pool = fs.collection('rewardCodes');
  const me = await call('referralStatus', 'late', { platform: 'ios' });
  for (const f of ['late-f1', 'late-f2', 'late-f3']) {
    await call('applyReferralCode', f, { platform: 'ios', code: me.code });
    await friendBuy(f);
  }
  await settle();
  const day = 24 * 60 * 60 * 1000;
  await pool.doc('ios_APPLE1').set({ platform: 'ios', code: 'APPLE1', assignedTo: null, expiresAt: new Date(Date.now() + 10 * day) });
  await pool.doc('ios_APPLE2').set({ platform: 'ios', code: 'APPLE2', assignedTo: null, expiresAt: new Date(Date.now() + 170 * day) });

  const first = await call('claimReferralReward', 'late', { platform: 'ios', reward: 'lifetime' });
  assert.equal(first.code, 'APPLE1');

  // Time passes: the code expires before it's redeemed.
  await fs.doc('referralUsers/late').update({ 'rewards.lifetime.codeExpiresAt': new Date(Date.now() - day) });
  const status = await call('referralStatus', 'late', { platform: 'ios' });
  assert.equal(status.tiers[2].state, 'earned');
  assert.equal(status.tiers[2].code, undefined);

  const second = await call('claimReferralReward', 'late', { platform: 'ios', reward: 'lifetime' });
  assert.equal(second.code, 'APPLE2');
  assert.equal((await pool.doc('ios_APPLE1').get()).data().expiredUnusedBy, 'late');
});

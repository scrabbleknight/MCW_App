// GENERATED from ViralEngine/funnel-kit/functions/test/commerce.test.js — edit it there and run `npm run funnel:sync`.
const test = require('node:test');
const assert = require('node:assert/strict');

const logic = require('../commerce/logic');

test('Apple free trial is a trial start, not paid', () => {
  const c = logic.classifyApple({
    offerType: 1,
    offerDiscountType: 'FREE_TRIAL',
    price: 0,
    currency: 'GBP',
    transactionReason: 'PURCHASE',
  });
  assert.equal(c.event, 'trial_start');
  assert.equal(c.offer, 'trial');
  assert.equal(c.paid, false);
  assert.equal(c.value, null);
});

test('Apple intro price (friend discount) is a paid purchase', () => {
  const c = logic.classifyApple({
    offerType: 1,
    offerDiscountType: 'PAY_UP_FRONT',
    price: 29990,
    currency: 'USD',
    transactionReason: 'PURCHASE',
  });
  assert.equal(c.event, 'purchase_verified');
  assert.equal(c.offer, 'intro');
  assert.equal(c.paid, true);
  assert.equal(c.value, 29.99);
});

test('Apple free promotional reward is recorded but not paid', () => {
  const c = logic.classifyApple({ offerType: 2, price: 0, transactionReason: 'PURCHASE' });
  assert.equal(c.event, 'purchase_verified');
  assert.equal(c.offer, 'promo');
  assert.equal(c.paid, false);
});

test("A trial's first renewal is a conversion; later ones are renewals", () => {
  const renewal = { price: 59990, currency: 'USD', transactionReason: 'RENEWAL' };
  assert.equal(
    logic.classifyApple(renewal, { offer: 'trial', paid: false }).event,
    'trial_converted_to_paid',
  );
  assert.equal(
    logic.classifyApple(renewal, { offer: 'none', paid: true }).event,
    'subscription_renewed',
  );
  const unknown = logic.classifyApple(renewal, null);
  assert.equal(unknown.event, 'subscription_renewed');
  assert.equal(unknown.priorUnknown, true);
});

test('Play phases: trial, intro, base', () => {
  const sub = (offerPhase) => ({ lineItems: [{ offerPhase }] });
  assert.equal(logic.classifyPlay(sub({ freeTrial: {} })).event, 'trial_start');
  assert.equal(logic.classifyPlay(sub({ freeTrial: {} })).paid, false);
  const intro = logic.classifyPlay(sub({ introductoryPrice: {} }));
  assert.deepEqual([intro.event, intro.offer, intro.paid], ['purchase_verified', 'intro', true]);
  assert.equal(logic.classifyPlay(sub({ basePrice: {} })).offer, 'none');
});

test('Transaction keys are stable and Firestore-safe', () => {
  assert.equal(logic.transactionKey('ios', 2000000123), 'ios_tx_2000000123');
  assert.equal(
    logic.transactionKey('android', 'GPA.3333-4444-5555-66666..0'),
    'android_tx_GPA.3333-4444-5555-66666..0',
  );
  assert.equal(logic.transactionKey('android', 'a/b'), 'android_tx_a_b');
});

test('Token hash matches Post-Bridge (sha256, 24 hex chars)', () => {
  assert.equal(logic.tokenHash('abc'), 'ba7816bf8f01cfea414140de');
});

test('Apple notifications map to lifecycle events', () => {
  assert.equal(logic.appleNotification('DID_CHANGE_RENEWAL_STATUS', 'AUTO_RENEW_DISABLED').event, 'subscription_cancelled');
  assert.equal(logic.appleNotification('DID_CHANGE_RENEWAL_STATUS', 'AUTO_RENEW_ENABLED'), null);
  assert.equal(logic.appleNotification('EXPIRED', 'VOLUNTARY').event, 'subscription_expired');
  assert.equal(logic.appleNotification('EXPIRED', 'VOLUNTARY').reason, 'VOLUNTARY');
  assert.equal(logic.appleNotification('DID_RENEW').keyed, 'transaction');
  assert.equal(logic.appleNotification('SUBSCRIBED', 'INITIAL_BUY').keyed, 'transaction');
  assert.equal(logic.appleNotification('REFUND').event, 'purchase_refunded');
  assert.equal(logic.appleNotification('TEST'), null);
});

test('latestBefore picks the newest earlier entry, skipping itself', () => {
  const t = (d) => new Date(`2026-10-${String(d).padStart(2, '0')}T00:00:00Z`);
  const entries = [
    { id: 'a', storeTime: t(1), offer: 'trial' },
    { id: 'b', storeTime: t(4), offer: 'none' },
    { id: 'c', storeTime: t(8), offer: 'none' },
  ];
  assert.equal(logic.latestBefore(entries, t(5), 'c').id, 'b');
  assert.equal(logic.latestBefore(entries, t(4), 'b').id, 'a');
  assert.equal(logic.latestBefore(entries, t(1), 'a'), null);
});

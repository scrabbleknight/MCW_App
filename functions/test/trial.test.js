const test = require('node:test');
const assert = require('node:assert');

const { trialTiming } = require('../trial/logic');

const t0 = new Date('2026-11-03T09:00:00Z');
const hours = (h) => new Date(t0.getTime() + h * 3600 * 1000);

const trial = { id: 'ios_tx_1', event: 'trial_start', paid: false, storeTime: t0 };

test('a cancellation inside the trial is timed from the trial start', () => {
  const cancel = { id: 'ios_n_a', event: 'subscription_cancelled', storeTime: hours(30.5) };
  const timing = trialTiming(cancel, [trial, cancel]);
  assert.deepStrictEqual(timing, {
    trialStartedAt: t0,
    hoursSinceTrialStart: 30,
    duringTrial: true,
  });
});

test('a cancellation after the trial converted is not during the trial', () => {
  const converted = { id: 'ios_tx_2', event: 'trial_converted_to_paid', paid: true, storeTime: hours(72) };
  const cancel = { id: 'ios_n_b', event: 'subscription_cancelled', storeTime: hours(200) };
  const timing = trialTiming(cancel, [trial, converted, cancel]);
  assert.strictEqual(timing.duringTrial, false);
  assert.strictEqual(timing.hoursSinceTrialStart, 200);
});

test('the conversion itself is timed and never during the trial', () => {
  const converted = { id: 'ios_tx_2', event: 'trial_converted_to_paid', paid: true, storeTime: hours(72) };
  const timing = trialTiming(converted, [trial, converted]);
  assert.strictEqual(timing.hoursSinceTrialStart, 72);
  assert.strictEqual(timing.duringTrial, false);
});

test('no trial on record, or an event that is not timed: nothing added', () => {
  const cancel = { id: 'ios_n_c', event: 'subscription_cancelled', storeTime: hours(5) };
  assert.strictEqual(trialTiming(cancel, [cancel]), null);
  const renewed = { id: 'ios_tx_3', event: 'subscription_renewed', storeTime: hours(400) };
  assert.strictEqual(trialTiming(renewed, [trial, renewed]), null);
});

test('a trial that started after the event does not count', () => {
  const cancel = { id: 'ios_n_d', event: 'subscription_cancelled', storeTime: hours(-2) };
  assert.strictEqual(trialTiming(cancel, [trial, cancel]), null);
});

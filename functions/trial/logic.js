/**
 * Pure rules for trial timing: how long after a trial started its
 * subscription was cancelled, converted, expired or refunded. No I/O, so
 * they're unit-tested (test/trial.test.js).
 */

const EVENTS = {
  trialStart: 'trial_start',
  trialConverted: 'trial_converted_to_paid',
  cancelled: 'subscription_cancelled',
  expired: 'subscription_expired',
  refunded: 'purchase_refunded',
};

/** Ledger events that get trial timing added. */
const TIMED = new Set([
  EVENTS.cancelled,
  EVENTS.trialConverted,
  EVENTS.expired,
  EVENTS.refunded,
]);

const HOUR = 60 * 60 * 1000;

/**
 * [entry] is a new ledger entry; [entries] are every ledger entry for the
 * same subscription (same originalId), storeTime as Dates. Returns the
 * fields to add to [entry], or null when it isn't timed or no trial is known
 * for it.
 *
 *   trialStartedAt        when the trial began
 *   hoursSinceTrialStart  whole hours from then to [entry]
 *   duringTrial           true when nothing paid had happened yet: a
 *                         cancellation inside the trial, or an expiry of a
 *                         trial that never converted
 */
function trialTiming(entry, entries) {
  if (!TIMED.has(entry.event) || !entry.storeTime) return null;
  const at = entry.storeTime.getTime();
  let trial = null;
  for (const e of entries) {
    if (e.event !== EVENTS.trialStart || !e.storeTime) continue;
    if (e.storeTime.getTime() > at) continue;
    if (!trial || e.storeTime < trial.storeTime) trial = e;
  }
  if (!trial) return null;
  const converted = entries.some(
    (e) =>
      e.id !== entry.id &&
      e.storeTime &&
      e.storeTime.getTime() <= at &&
      (e.event === EVENTS.trialConverted || (e.paid === true && e.event !== EVENTS.trialStart)),
  );
  return {
    trialStartedAt: trial.storeTime,
    hoursSinceTrialStart: Math.max(0, Math.floor((at - trial.storeTime.getTime()) / HOUR)),
    duringTrial: entry.event === EVENTS.trialConverted ? false : !converted,
  };
}

module.exports = { EVENTS, TIMED, trialTiming };

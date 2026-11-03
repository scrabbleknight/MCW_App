const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const { REGION } = require('../referrals/config');
const logic = require('./logic');

/**
 * Adds trial timing to the commerce ledger (commerceEvents, written by the
 * shared funnel-kit code in ../commerce): when a subscription that began
 * with a free trial is cancelled, converts, expires or is refunded, the
 * entry gets trialStartedAt, hoursSinceTrialStart and duringTrial.
 *
 * iOS lifecycle entries come from App Store Server Notifications, so a
 * cancellation is timed to the moment auto-renew was turned off, whether or
 * not the app is opened again. Android's lifecycle notifications go to
 * Post-Bridge rather than this ledger; the app's own trial_cancelled event
 * covers Android (lib/core/funnel/trial_engagement.dart).
 *
 * Reads and writes only the ledger, which holds no user id, name or email.
 * scripts/trial-report.js summarises it.
 */
exports.timeTrialEvents = onDocumentCreated(
  { document: 'commerceEvents/{key}', region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data || !logic.TIMED.has(data.event) || !data.originalId) return;
    const entry = { id: event.params.key, ...data, storeTime: data.storeTime?.toDate?.() ?? null };
    const snap = await getFirestore()
      .collection('commerceEvents')
      .where('originalId', '==', data.originalId)
      .get();
    const entries = snap.docs.map((d) => {
      const v = d.data();
      return { id: d.id, ...v, storeTime: v.storeTime?.toDate?.() ?? null };
    });
    const timing = logic.trialTiming(entry, entries);
    if (!timing) return;
    await event.data.ref.update({
      ...timing,
      trialStartedAt: Timestamp.fromDate(timing.trialStartedAt),
    });
    logger.info('Trial timing', {
      event: data.event,
      platform: data.platform,
      environment: data.environment,
      hoursSinceTrialStart: timing.hoursSinceTrialStart,
      duringTrial: timing.duringTrial,
    });
  },
);

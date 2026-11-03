#!/usr/bin/env node
/**
 * Trial outcomes from the commerce ledger (commerceEvents): trials started,
 * how many were cancelled inside the trial and how soon, and how many
 * converted. Production entries only. iOS is complete (App Store Server
 * Notifications); Android lifecycle events go to Post-Bridge, so Android
 * shows trial starts only. Cancellations are timed by timeTrialEvents
 * (functions/trial), so only those from after it was deployed have hours.
 *
 *   node scripts/trial-report.js          # the last 30 days
 *   node scripts/trial-report.js 90
 *
 * Runs as you: `gcloud auth application-default login` first.
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const days = Number(process.argv[2] ?? 30);
initializeApp({ credential: applicationDefault(), projectId: 'military-calisthenics-women' });

const median = (xs) => {
  if (xs.length === 0) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

async function main() {
  const since = Timestamp.fromMillis(Date.now() - days * 24 * 3600 * 1000);
  const snap = await getFirestore()
    .collection('commerceEvents')
    .where('storeTime', '>=', since)
    .get();
  const rows = snap.docs.map((d) => d.data()).filter((e) => e.environment === 'production');

  for (const platform of ['ios', 'android']) {
    const mine = rows.filter((e) => e.platform === platform);
    const trials = mine.filter((e) => e.event === 'trial_start');
    const cancels = mine.filter((e) => e.event === 'subscription_cancelled' && e.duringTrial === true);
    const converted = mine.filter((e) => e.event === 'trial_converted_to_paid');
    const hours = cancels.map((e) => e.hoursSinceTrialStart).filter((h) => typeof h === 'number');
    const buckets = { '<1h': 0, '1-24h': 0, '24-48h': 0, '48h+': 0 };
    for (const h of hours) {
      if (h < 1) buckets['<1h']++;
      else if (h < 24) buckets['1-24h']++;
      else if (h < 48) buckets['24-48h']++;
      else buckets['48h+']++;
    }
    console.log(`\n${platform.toUpperCase()} — last ${days} days`);
    console.log(`  trials started:              ${trials.length}`);
    console.log(`  cancelled during the trial:  ${cancels.length}`);
    console.log(`  median hours to cancel:      ${median(hours) ?? '–'}`);
    console.log(`  cancel timing:               ${JSON.stringify(buckets)}`);
    console.log(`  converted to paid:           ${converted.length}`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

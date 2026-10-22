#!/usr/bin/env node
/**
 * Loads single-use Lifetime codes into the pool claimReferralReward hands
 * out from (Firestore rewardCodes). Codes already in the pool are skipped,
 * so re-running with the same file is safe.
 *
 *   node scripts/load-reward-codes.js ios codes.csv 2027-04-20
 *   node scripts/load-reward-codes.js android codes.txt 2027-10-20
 *
 * The date is when the batch expires, as set in the store (Apple's one-time
 * codes last at most 6 months; Play promotions up to a year). The server
 * only hands out codes with at least a week left, and checkRewardCodes logs
 * an error each Monday when fewer than 10 usable codes are left, so load a
 * fresh batch before the current one runs out or expires.
 *
 * iOS: App Store Connect → Lifetime in-app purchase → Offer Codes →
 * one-time-use codes → download the CSV. Android: Play Console → Monetise →
 * Promo codes → a promotion for the Lifetime product → download the codes.
 * Any file with one code per line works; the first column of a CSV is used.
 *
 * Runs as you: `gcloud auth application-default login` first.
 */
const fs = require('node:fs');
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const [platform, file, expiry] = process.argv.slice(2);
const expiresAt = expiry ? new Date(`${expiry}T00:00:00Z`) : null;
if (
  !['ios', 'android'].includes(platform) ||
  !file ||
  !expiresAt ||
  Number.isNaN(expiresAt.getTime())
) {
  console.error(
    'Usage: load-reward-codes.js <ios|android> <file> <expiry YYYY-MM-DD>',
  );
  process.exit(1);
}

const codes = fs
  .readFileSync(file, 'utf8')
  .split(/\r?\n/)
  .map((line) => line.split(',')[0].trim().replace(/^"|"$/g, ''))
  .filter((code) => /^[A-Za-z0-9]{4,}$/.test(code));

async function main() {
  initializeApp({
    credential: applicationDefault(),
    projectId: 'military-calisthenics-women',
  });
  const pool = getFirestore().collection('rewardCodes');
  let added = 0;
  for (let i = 0; i < codes.length; i += 400) {
    const batch = getFirestore().batch();
    for (const code of codes.slice(i, i + 400)) {
      // create() fails on an existing doc, so a re-run can't reset an
      // assigned code; those writes are counted as skipped below.
      batch.create(pool.doc(`${platform}_${code}`), {
        platform,
        code,
        assignedTo: null,
        assignedAt: null,
        expiresAt,
        loadedAt: FieldValue.serverTimestamp(),
      });
    }
    try {
      await batch.commit();
      added += Math.min(400, codes.length - i);
    } catch (error) {
      // One existing code fails the whole batch; fall back to one by one.
      for (const code of codes.slice(i, i + 400)) {
        try {
          await pool.doc(`${platform}_${code}`).create({
            platform,
            code,
            assignedTo: null,
            assignedAt: null,
            expiresAt,
            loadedAt: FieldValue.serverTimestamp(),
          });
          added++;
        } catch {
          // Already loaded.
        }
      }
    }
  }
  console.log(`Loaded ${added} new ${platform} codes (${codes.length - added} skipped).`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

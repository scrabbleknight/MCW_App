# Release 1 — 1.0.5 (16): trial analytics and Crashlytics

Branch `release1/trial-analytics-crashlytics`, from `origin/main` (1.0.4+15, live on Google Play).
No change to the onboarding flow, trial length, prices or paywall.

## What trial users do: new Analytics events

MCW-only, in `lib/core/funnel/trial_engagement.dart` (the shared funnel kit files are generated from
ViralEngine, so they're untouched). Every event carries `sub_state` (`none` / `trial` /
`trial_cancelled` / `paid`) and, once a trial or access start is known, `trial_day` (calendar days
since the trial started). `sub_state` is also a user property, so any GA report can be split by it.

| Question | Event(s) | Notes |
|---|---|---|
| Trial started | `trial_start` (existing) | Server-verified. Also starts the trial clock on the phone. |
| First workout started | `first_workout_started`, `workout_started` (`workout_number`) | Once per install / every workout |
| First workout completed | `first_workout_completed`, `workout_completed` (`duration_sec`) | |
| Gave up mid-workout | `workout_quit` (`percent_done`, `duration_sec`, `reason`) | `reason` is the quit screen's choice, never the typed note |
| Second session started | `second_session_started` (`hours_since_first_workout`) | The second workout started |
| Return on day 1 / day 2 | `return_day_1`, `return_day_2` | App opened on the 1st / 2nd calendar day after the trial started |
| Trial cancelled | `trial_cancelled` (`hours_since_trial_start`, `workouts_completed`) | Seen on the next app open (iOS: StoreKit 2 renewal info; Android: Play `isAutoRenewing`), so the hours are an upper bound |
| Subscription converted | `subscription_converted` (`hours_since_trial_start`) | iOS: StoreKit says the period is paid; Android: still auto-renewing a day after the trial's end |
| Time in app | `visit_end` (`duration_sec`, `workouts_completed`, `in_onboarding`) + Firebase's own engagement time | One per foreground visit |
| Onboarding drop-off | `onboarding_step_view` (existing) + `onboarding_exit` (`screen_id`, `step_index`, `sec_on_screen`, `sec_in_onboarding`) | `onboarding_exit` is the screen the app was backgrounded on |

### Exact cancellation timing (iOS)

The app only sees a cancellation when it's opened again. Apple tells the server immediately (App Store
Server Notifications → `commerceEvents`). The new `timeTrialEvents` Firestore trigger
(`functions/trial/`) adds `trialStartedAt`, `hoursSinceTrialStart` and `duringTrial` to each
cancellation / conversion / expiry / refund entry. `node functions/scripts/trial-report.js [days]`
prints trials started, cancelled during the trial, median hours to cancel, and conversions.
Android lifecycle notifications go to Post-Bridge, not this ledger, so Android relies on the app event.

## Crash reporting

Firebase Crashlytics 5.1.0 (matches the pinned firebase_core 4.6.0):

- Off natively (`FirebaseCrashlyticsCollectionEnabled` / `firebase_crashlytics_collection_enabled`),
  switched on by `lib/core/diagnostics/crash_reporting.dart` only with analytics consent. Reports made
  before the answer are sent on yes and deleted on no.
- Never in debug builds (unless `--dart-define=CRASHLYTICS_IN_DEBUG=true`).
- Uncaught Dart errors and Flutter framework errors are recorded as fatal; native crashes as usual.
- iOS: a "[firebase_crashlytics] Crashlytics Upload Symbols" build phase uploads dSYMs for release
  archives. Android: the Crashlytics Gradle plugin uploads the mapping file.
- Test: build with `--dart-define=CRASHLYTICS_TEST_CRASH=true` and the app records a non-fatal and
  then crashes once, 5 s after consent; the report uploads on the next launch.

## Privacy

- Only with analytics consent, and only from store installs (the funnel's existing environment
  check: no simulators, emulators, TestFlight, Test Lab or debug builds). Nothing is queued before
  consent.
- No user id is set in Analytics or Crashlytics. Identifiers are Firebase's random app-instance id
  and Crashlytics' random installation id.
- Only counts, durations, product ids, screen ids and enum names are sent: no onboarding answers,
  health details or typed text.

## Store declarations to update before submitting

- App Store Connect → App Privacy: add **Diagnostics → Crash Data** (not linked to the user, not used
  for tracking; purpose App Functionality). Analytics usage data is already declared.
- Play Console → Data safety: add **App info and performance → Crash logs and Diagnostics**
  (collected, not shared, optional, purpose App functionality / Analytics).
- The privacy policy (deepblue.org.uk/privacy-policy) already covers crash and error logs.

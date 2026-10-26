# military_calisthenics_women

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Subscriptions

UK prices (changed 2026-10-26: Monthly replaced Weekly). The paywall shows the
store's price once it loads; its fallback matches these.

| Plan | iOS product | Android product | Price |
|---|---|---|---|
| Monthly | `com.swiftbee.militarycalisthenicswomen.monthly` | `com.swiftbee.militarycalisthenics.monthly` | £14.99 / month (US $19.99), no trial |
| Yearly | `com.swiftbee.militarycalisthenicswomen.annual` | `com.swiftbee.militarycalisthenics.annual` | £49.99 / year (US $64.99), free trial unchanged |
| Yearly, friend twin (iOS) | `com.swiftbee.militarycalisthenicswomen.annual.friend` | `referral-friend` offer on the annual base plan | 50% off the first year (£24.99), then £49.99 |
| Weekly (no longer sold) | `com.swiftbee.militarycalisthenicswomen.weekly` | `com.swiftbee.militarycalisthenics.weekly` | Existing subscribers only |

Referral reward offers on iOS (promotional offers, `functions/referrals/config.js`):
`ref_half1y_annual` on Annual, `ref_free1y_annual` on Annual,
`ref_free1y_monthly` on Monthly (new) and `ref_free1y_weekly` on Weekly
(kept for existing weekly subscribers).

The app still queries and recognises the Weekly products so existing weekly
subscribers stay unlocked, can restore, and can claim referral rewards.

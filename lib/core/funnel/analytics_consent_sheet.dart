// GENERATED from ViralEngine/funnel-kit/dart/analytics_consent_sheet.dart — edit it there and run `npm run funnel:sync`.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'funnel_tracker.dart';

/// Asks for analytics consent if the user hasn't answered yet, and returns
/// once they have. Allow and Don't allow are the same size and weight, and
/// the answer can be changed in Settings ([showAnalyticsConsentSheet] with
/// `force: true`).
Future<void> showAnalyticsConsentSheet(
  BuildContext context, {
  required FunnelTracker tracker,
  required String appName,
  required Uri privacyPolicy,
  bool force = false,
}) async {
  if (!force && tracker.consent != AnalyticsConsent.unknown) return;
  final granted = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: force,
    enableDrag: force,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ConsentSheet(
      appName: appName,
      privacyPolicy: privacyPolicy,
      current: tracker.consent,
    ),
  );
  if (granted != null) await tracker.setConsent(granted);
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet({
    required this.appName,
    required this.privacyPolicy,
    required this.current,
  });

  final String appName;
  final Uri privacyPolicy;
  final AnalyticsConsent current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.45);
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      textStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Help us improve $appName?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'With your permission, we use Google Analytics for Firebase to '
            'count which screens people reach and whether they start a '
            'subscription. It helps us see where the app is confusing.',
            style: body,
          ),
          const SizedBox(height: 10),
          Text(
            'We never send your answers, health details, name or email. '
            "The app works the same either way, and you can change this "
            'any time in Settings.',
            style: body,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => launchUrl(
                privacyPolicy,
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Privacy Policy'),
            ),
          ),
          if (current != AnalyticsConsent.unknown) ...[
            Text(
              current == AnalyticsConsent.granted
                  ? 'Currently: allowed'
                  : 'Currently: not allowed',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('analytics-consent-deny'),
                  style: buttonStyle,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Don't allow"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const Key('analytics-consent-allow'),
                  style: buttonStyle,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Allow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

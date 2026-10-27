// GENERATED from ViralEngine/funnel-kit/dart/analytics_consent_sheet.dart — edit it there and run `npm run funnel:sync`.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'funnel_tracker.dart';

/// The sheet's words. Apps with their own translations pass them in;
/// otherwise it's [ConsentSheetText.english].
class ConsentSheetText {
  const ConsentSheetText({
    required this.title,
    required this.purpose,
    required this.promise,
    required this.privacyPolicy,
    required this.currentlyAllowed,
    required this.currentlyNotAllowed,
    required this.deny,
    required this.allow,
  });

  ConsentSheetText.english(String appName)
    : title = 'Help us improve $appName?',
      purpose =
          'With your permission, we use Google Analytics for Firebase to '
          'understand how the app is used, so we can keep making it better.',
      promise =
          'We never send your answers, health details, name or email. '
          'The app works the same either way, and you can change this '
          'any time in Settings.',
      privacyPolicy = 'Privacy Policy',
      currentlyAllowed = 'Currently: allowed',
      currentlyNotAllowed = 'Currently: not allowed',
      deny = "Don't allow",
      allow = 'Allow';

  final String title;
  final String purpose;
  final String promise;
  final String privacyPolicy;
  final String currentlyAllowed;
  final String currentlyNotAllowed;
  final String deny;
  final String allow;
}

/// Asks for analytics consent if the user hasn't answered yet, and returns
/// once they have. Allow and Don't allow are the same size and weight, and
/// the answer can be changed in Settings ([showAnalyticsConsentSheet] with
/// `force: true`). [text] defaults to English.
Future<void> showAnalyticsConsentSheet(
  BuildContext context, {
  required FunnelTracker tracker,
  required String appName,
  required Uri privacyPolicy,
  bool force = false,
  ConsentSheetText? text,
}) async {
  if (!force && tracker.consent != AnalyticsConsent.unknown) return;
  final granted = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: force,
    enableDrag: force,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ConsentSheet(
      text: text ?? ConsentSheetText.english(appName),
      privacyPolicy: privacyPolicy,
      current: tracker.consent,
    ),
  );
  if (granted != null) await tracker.setConsent(granted);
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet({
    required this.text,
    required this.privacyPolicy,
    required this.current,
  });

  final ConsentSheetText text;
  final Uri privacyPolicy;
  final AnalyticsConsent current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.45);
    // Narrow side padding so longer translations ("Ne pas autoriser") stay
    // on one line, centred if they don't: both buttons always match.
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            text.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(text.purpose, style: body),
          const SizedBox(height: 10),
          Text(text.promise, style: body),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => launchUrl(
                privacyPolicy,
                mode: LaunchMode.externalApplication,
              ),
              child: Text(text.privacyPolicy),
            ),
          ),
          if (current != AnalyticsConsent.unknown) ...[
            Text(
              current == AnalyticsConsent.granted
                  ? text.currentlyAllowed
                  : text.currentlyNotAllowed,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          // Same height too when one label wraps and the other doesn't.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('analytics-consent-deny'),
                    style: buttonStyle,
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(text.deny, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('analytics-consent-allow'),
                    style: buttonStyle,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(text.allow, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The words behind the small print's (i). Apps with their own translations
/// pass them in; otherwise it's [AnalyticsNoteText.english].
class AnalyticsNoteText {
  const AnalyticsNoteText({
    required this.tooltip,
    required this.note,
    required this.privacyPolicy,
  });

  const AnalyticsNoteText.english()
    : tooltip = 'About analytics',
      note =
          'We use Google Analytics for Firebase to understand how the app is '
          'used, so we can keep making it better. We never send your name, '
          'email or health details. You can turn this off any time in '
          'Settings.',
      privacyPolicy = 'Privacy Policy';

  final String tooltip;
  final String note;
  final String privacyPolicy;
}

/// Welcome's small print ([child], e.g. "By continuing you agree to the
/// Terms of Use") with an (i) beside it that says what analytics is for.
/// Continuing turns analytics on ([FunnelTracker.acceptByContinuing]);
/// Settings turns it off ([showAnalyticsConsentSheet] with `force: true`).
class AnalyticsSmallPrint extends StatelessWidget {
  const AnalyticsSmallPrint({
    super.key,
    required this.child,
    required this.privacyPolicy,
    this.color,
    this.text = const AnalyticsNoteText.english(),
  });

  final Widget child;
  final Uri privacyPolicy;

  /// The (i)'s colour; match the small print's.
  final Color? color;
  final AnalyticsNoteText text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: child),
        IconButton(
          key: const Key('analytics-info'),
          tooltip: text.tooltip,
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          color: color,
          onPressed: () => _showNote(context),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    );
  }

  void _showNote(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text.note, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () =>
                launchUrl(privacyPolicy, mode: LaunchMode.externalApplication),
            child: Text(text.privacyPolicy),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

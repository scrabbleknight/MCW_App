import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/funnel/recovery_offer.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/haptics.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// How the recovery offer ended.
enum RecoveryResult { purchased, declined }

/// The paywall exit recovery offer, over the paywall. Completes with
/// [RecoveryResult.purchased] once the store confirms the purchase, or
/// [RecoveryResult.declined] for "No thanks", Android back or a close.
/// [leaving]: declining closes the app, so the button says so.
Future<RecoveryResult> showRecoveryOffer(
  BuildContext context, {
  required RecoveryOfferTerms terms,
  required bool leaving,
  required String placement,
}) async {
  final result = await Navigator.of(context).push<RecoveryResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RecoveryOfferScreen(
        terms: terms,
        leaving: leaving,
        placement: placement,
      ),
    ),
  );
  return result ?? RecoveryResult.declined;
}

class RecoveryOfferScreen extends StatefulWidget {
  const RecoveryOfferScreen({
    super.key,
    required this.terms,
    required this.leaving,
    required this.placement,
  });

  final RecoveryOfferTerms terms;
  final bool leaving;
  final String placement;

  @override
  State<RecoveryOfferScreen> createState() => _RecoveryOfferScreenState();
}

class _RecoveryOfferScreenState extends State<RecoveryOfferScreen> {
  bool _buying = false;

  /// Set once the result is decided, so the pop handler doesn't log a
  /// decline on top of it.
  bool _done = false;

  late final RecoveryOfferCopy _copy = RecoveryOfferCopy(
    widget.terms,
    isAndroid: StorePlatform.isAndroid,
  );

  Map<String, Object> get _params => widget.terms.analyticsParams();

  Future<void> _claim() async {
    if (_buying) return;
    final funnel = context.read<FunnelTracker>();
    final purchases = context.read<PurchaseController>();
    funnel.recoveryOfferAccepted(_params);
    setState(() => _buying = true);
    final outcome = await purchases.purchaseRecovery(
      placement: widget.placement,
    );
    if (!mounted) return;
    setState(() => _buying = false);
    if (outcome == PurchaseOutcome.success) {
      _done = true;
      Navigator.of(context).pop(RecoveryResult.purchased);
      return;
    }
    funnel.recoveryOfferPurchaseFailed(
      _params,
      category: switch (outcome) {
        PurchaseOutcome.cancelled => PurchaseFailure.cancelled,
        PurchaseOutcome.storeUnavailable => PurchaseFailure.storeUnavailable,
        PurchaseOutcome.productNotFound => PurchaseFailure.productUnavailable,
        PurchaseOutcome.pending => PurchaseFailure.pending,
        _ => PurchaseFailure.unknown,
      },
    );
    // Closing the store's sheet is a choice, not an error; they can still
    // claim or decline here.
    if (outcome != PurchaseOutcome.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't complete the purchase. Please try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _decline() {
    if (_buying) return;
    _done = true;
    context.read<FunnelTracker>().recoveryOfferDeclined(
      _params,
      method: 'no_thanks',
    );
    Navigator.of(context).pop(RecoveryResult.declined);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      // No leaving mid-purchase; otherwise back is the same as "No thanks".
      canPop: !_buying,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || _done) return;
        _done = true;
        context.read<FunnelTracker>().recoveryOfferDeclined(
          _params,
          method: 'back',
        );
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Gift(),
                const SizedBox(height: 18),
                Text(
                  _copy.headline,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _copy.subhead,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 22),
                _OfferCard(terms: widget.terms),
                const SizedBox(height: 18),
                _Timeline(steps: _copy.timeline),
                const SizedBox(height: 22),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: OnboardingHaptics.onPress(
                      _buying ? null : _claim,
                    ),
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    child: _buying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Colors.white,
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _copy.primaryCta,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: OnboardingHaptics.onTap(
                      _buying ? null : _decline,
                    ),
                    child: Text(
                      _copy.declineCta(leaving: widget.leaving),
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _copy.disclosure,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const _Links(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Gift extends StatelessWidget {
  const _Gift();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.12),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: const Text('🎁', style: TextStyle(fontSize: 44, height: 1)),
      ),
    );
  }
}

/// The offer at a glance: the free days, then what the first month and
/// every month after cost.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.terms});
  final RecoveryOfferTerms terms;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = scheme.onSurface.withValues(alpha: 0.70);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.08),
              scheme.surface,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.primary, width: 1.8),
          ),
          child: Column(
            children: [
              Text(
                '${terms.trialDays} DAYS FREE',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              if (terms.hasDiscount) ...[
                Text.rich(
                  TextSpan(
                    style: text.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      const TextSpan(text: 'then '),
                      TextSpan(
                        text: terms.regularPrice,
                        style: TextStyle(
                          color: muted,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: terms.discountedPrice,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const TextSpan(text: ' for your first month'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'then ${terms.regularPrice}/month',
                  style: text.bodyMedium?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                Text(
                  'then ${terms.regularPrice}/month',
                  style: text.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        if (terms.hasDiscount)
          Positioned(
            right: 16,
            top: -12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${terms.discountPercent}% OFF MONTH 1',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      const SizedBox(height: 3),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: scheme.onSurface.withValues(alpha: 0.18),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].$2,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Links extends StatelessWidget {
  const _Links();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.65),
      fontWeight: FontWeight.w500,
    );
    Widget link(String label, String url) => InkWell(
      onTap: OnboardingHaptics.onTap(
        () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(label, style: style),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        link('Terms', 'https://deepblue.org.uk/terms-of-use'),
        const SizedBox(width: 20),
        link('Privacy', 'https://deepblue.org.uk/privacy-policy'),
      ],
    );
  }
}

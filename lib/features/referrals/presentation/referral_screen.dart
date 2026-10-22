import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:military_calisthenics_women/features/referrals/application/referral_controller.dart';

/// The user's referral code, how many friends have subscribed with it, and
/// the rewards that earns (1 friend: 50% off for a year, 2: a free year,
/// 3: free for life).
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  /// iOS: rewards whose Apple offer was bought on this phone. Apple applies
  /// it from the next renewal, so the server may not see it straight away.
  static const _kAppliedOnDevice = 'referral.applied_on_device';

  String? _error;
  ReferralReward? _claiming;
  Set<String> _appliedOnDevice = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      _appliedOnDevice = (prefs.getStringList(_kAppliedOnDevice) ?? []).toSet();
    } catch (_) {
      // Only hides a Claim button that would work anyway.
    }
    if (!mounted) return;
    try {
      await context.read<ReferralController>().refresh(createAccount: true);
    } on ReferralException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              "Couldn't load your code. Check your connection and try again.",
        );
      }
    }
  }

  Future<void> _share(String code) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            "I'm training with Military Calisthenics for Women. Use my code "
            '$code for 50% off your first year: https://mcwapp.web.app',
      ),
    );
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _snack('Code copied.');
  }

  Future<void> _claim(ReferralTier tier) async {
    if (_claiming != null) return;
    setState(() => _claiming = tier.reward);
    try {
      if (tier.reward == ReferralReward.lifetime) {
        await _claimLifetime();
      } else {
        await _claimSubscriptionReward(tier.reward);
      }
    } on ReferralException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  Future<void> _claimSubscriptionReward(ReferralReward reward) async {
    final referrals = context.read<ReferralController>();
    final purchases = context.read<PurchaseController>();
    if (purchases.currentPlan == null) await purchases.restore();
    final plan = purchases.currentPlan;
    if (plan == null) {
      _snack(
        'This reward applies to a subscription, and we couldn\'t find an '
        'active one on this ${StorePlatform.billingAccountName}.',
      );
      return;
    }

    final claim = await referrals.claim(
      reward,
      plan: plan,
      verificationData: StorePlatform.isAndroid
          ? purchases.currentVerificationData
          : null,
    );
    switch (claim) {
      case DeferredClaim(:final renewsAt):
        _snack(
          renewsAt == null
              ? 'Done! Your next payment has been pushed back.'
              : 'Done! Your next payment is now on '
                    '${DateFormat.yMMMMd().format(renewsAt.toLocal())}.',
        );
      case ScheduledClaim(:final appliesAt):
        _snack(
          appliesAt == null
              ? 'Done! Your free days are added after 182 more days '
                    'subscribed.'
              : 'Done! Stay subscribed and your 182 free days are added on '
                    '${DateFormat.yMMMMd().format(appliesAt.toLocal())}.',
        );
      case PromotionalOfferClaim(:final offer):
        final outcome = await purchases.purchaseWithPromotionalOffer(offer);
        if (outcome == PurchaseOutcome.success) {
          await _rememberApplied(reward);
          _snack('Done! Your reward has been applied.');
        } else if (outcome != PurchaseOutcome.cancelled) {
          _snack("Couldn't apply the reward. Please try again.");
        }
      case CodeClaim():
        break;
    }
  }

  Future<void> _claimLifetime() async {
    final claim = await context.read<ReferralController>().claim(
      ReferralReward.lifetime,
    );
    if (claim is CodeClaim && mounted) {
      await _showLifetimeCode(claim.code, claim.redeemUrl);
    }
  }

  Future<void> _showLifetimeCode(String code, Uri redeemUrl) {
    final p = context.palette;
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Free for life',
          style: TextStyle(color: p.chalk, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Redeem this code in the ${StorePlatform.storeName} to unlock '
              'Military Calisthenics Lifetime:',
              style: TextStyle(color: p.mist, height: 1.35),
            ),
            const SizedBox(height: 14),
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.chalk,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Once it's redeemed, cancel your current subscription in "
              "Manage Subscription so you aren't charged again.",
              style: TextStyle(color: p.muted, fontSize: 13, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => launchUrl(
              StorePlatform.manageSubscriptionsUri,
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Manage Subscription'),
          ),
          FilledButton(
            onPressed: () =>
                launchUrl(redeemUrl, mode: LaunchMode.externalApplication),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  Future<void> _rememberApplied(ReferralReward reward) async {
    setState(() => _appliedOnDevice = {..._appliedOnDevice, reward.id});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kAppliedOnDevice, _appliedOnDevice.toList());
    } catch (_) {}
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final referrals = context.watch<ReferralController>();
    final status = referrals.status;

    return Scaffold(
      backgroundColor: p.abyss,
      appBar: AppBar(
        backgroundColor: p.abyss,
        elevation: 0,
        iconTheme: IconThemeData(color: p.chalk),
      ),
      body: SafeArea(
        top: false,
        child: switch ((status, _error)) {
          (null, final error?) => _ErrorState(message: error, onRetry: _load),
          (null, _) => Center(
            child: CircularProgressIndicator(color: p.arctic),
          ),
          (final status?, _) => RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Text(
                  'Refer Friends',
                  style: TextStyle(
                    color: p.chalk,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Friends get 50% off their first year. When they '
                  'subscribe with your code, you earn rewards — up to '
                  'free for life.',
                  style: TextStyle(
                    color: p.chalk.withValues(alpha: 0.9),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                _CodeCard(
                  code: status.code,
                  onCopy: () => _copy(status.code),
                  onShare: () => _share(status.code),
                ),
                const SizedBox(height: 28),
                _Progress(status: status),
                const SizedBox(height: 14),
                for (final tier in status.tiers)
                  _TierRow(
                    tier: tier,
                    appliedOnDevice: _appliedOnDevice.contains(tier.reward.id),
                    claiming: _claiming == tier.reward,
                    onClaim: () => _claim(tier),
                    onShowCode: tier.code == null || tier.redeemUrl == null
                        ? null
                        : () => _showLifetimeCode(tier.code!, tier.redeemUrl!),
                  ),
                const SizedBox(height: 16),
                Text(
                  StorePlatform.isAndroid
                      ? 'A friend counts once they subscribe with your code. '
                            'Google Play applies subscription rewards by '
                            'moving your next payment back. 50% off for a '
                            'year: stay subscribed for 182 days and the next '
                            '182 are free. A free year adds 365 free days.'
                      : 'A friend counts once they subscribe with your code. '
                            'Rewards are applied through the App Store: the '
                            'half-price year is a year of Annual, and a free '
                            'year starts from your next renewal.',
                  style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR CODE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: TextStyle(
                  color: p.chalk,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                onPressed: onCopy,
                icon: Icon(Icons.copy_rounded, color: p.mist, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            label: const Text('SHARE MY CODE'),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.status});
  final ReferralStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final goal = status.tiers.isEmpty ? 1 : status.tiers.last.friends;
    final friends = status.friends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          friends == 1 ? '1 friend subscribed' : '$friends friends subscribed',
          style: TextStyle(
            color: p.chalk,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (friends / goal).clamp(0.0, 1.0),
            minHeight: 8,
            color: p.arctic,
            backgroundColor: p.surfaceHigh,
          ),
        ),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.appliedOnDevice,
    required this.claiming,
    required this.onClaim,
    required this.onShowCode,
  });

  final ReferralTier tier;
  final bool appliedOnDevice;
  final bool claiming;
  final VoidCallback onClaim;
  final VoidCallback? onShowCode;

  String get _title => switch (tier.reward) {
    ReferralReward.halfOffYear => '50% off for 1 year',
    ReferralReward.freeYear => 'Free for 1 year',
    ReferralReward.lifetime => 'Free for life',
  };

  String get _subtitle {
    final friends = tier.friends == 1 ? '1 friend' : '${tier.friends} friends';
    return switch (tier.state) {
      RewardState.locked => friends,
      RewardState.earned when appliedOnDevice => 'Applied',
      RewardState.earned => 'Earned — ready to claim',
      RewardState.redeeming => 'Applying…',
      RewardState.scheduled =>
        tier.appliesAt == null
            ? 'Free days added after 182 days subscribed'
            : 'Free days added on '
                  '${DateFormat.yMMMd().format(tier.appliesAt!.toLocal())}',
      RewardState.codeIssued => 'Code ready to redeem',
      RewardState.redeemed => 'Claimed',
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final unlocked = tier.state != RewardState.locked;
    final Widget trailing = switch (tier.state) {
      _ when claiming => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      RewardState.locked => Icon(Icons.lock_rounded, color: p.muted, size: 20),
      RewardState.earned when appliedOnDevice => Icon(
        Icons.check_circle_rounded,
        color: p.success,
      ),
      RewardState.earned => FilledButton(
        onPressed: onClaim,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Text('CLAIM'),
      ),
      RewardState.redeeming => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      RewardState.scheduled => Icon(Icons.schedule_rounded, color: p.mist),
      RewardState.codeIssued => TextButton(
        onPressed: onShowCode ?? onClaim,
        child: const Text('View code'),
      ),
      RewardState.redeemed => Icon(
        Icons.check_circle_rounded,
        color: p.success,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: unlocked ? p.arctic.withValues(alpha: 0.10) : p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? p.arctic : p.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? p.arctic : p.surfaceHigh,
            ),
            child: Text(
              '${tier.friends}',
              style: TextStyle(
                color: unlocked ? Colors.white : p.mist,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    color: p.chalk,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_subtitle, style: TextStyle(color: p.mist, fontSize: 13)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.mist, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
        ],
      ),
    );
  }
}

/// Profile entry point for the referral programme.
class InviteFriendsCard extends StatelessWidget {
  const InviteFriendsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final status = context.watch<ReferralController>().status;
    final friends = status?.friends ?? 0;
    final subtitle = friends == 0
        ? 'Friends get 50% off. You can earn free for life.'
        : friends == 1
        ? '1 friend subscribed'
        : '$friends friends subscribed';
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ReferralScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.arctic.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.card_giftcard_rounded, color: p.arctic),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refer Friends',
                      style: TextStyle(
                        color: p.chalk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: p.mist,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

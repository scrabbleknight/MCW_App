import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/notifications/notifications_controller.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

/// Onboarding beat that asks for push-notification permission. CONTINUE
/// pops the OS prompt; "Not Right Now" advances without asking.
class GetNotifiedStep extends StatefulWidget {
  const GetNotifiedStep({
    super.key,
    required this.onDecided,
    this.controller = const NotificationsController(),
  });

  /// Called once the user has either responded to the system prompt or
  /// tapped the skip link. [granted] reflects the user's actual OS choice
  /// (or false when they skipped).
  final ValueChanged<bool> onDecided;

  final NotificationsController controller;

  @override
  State<GetNotifiedStep> createState() => _GetNotifiedStepState();
}

class _GetNotifiedStepState extends State<GetNotifiedStep> {
  bool _prompting = false;

  Future<void> _requestAndAdvance() async {
    if (_prompting) return;
    setState(() => _prompting = true);
    final result = await widget.controller.requestPermission();
    if (!mounted) return;
    setState(() => _prompting = false);
    widget.onDecided(result == NotificationsPermission.granted);
  }

  void _skip() => widget.onDecided(false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Center(
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: scheme.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Get Notified',
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep up with content updates, reminder of workout time, '
                'special offer',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              const Expanded(child: _PhonePreview()),
            ],
          ),
        ),
        TextButton(
          onPressed: _prompting ? null : _skip,
          child: Text(
            'Not Right Now',
            style: text.titleSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 6),
        PrimaryCta(
          label: 'CONTINUE',
          trailingIcon: null,
          onPressed: _prompting ? null : _requestAndAdvance,
        ),
      ],
    );
  }
}

/// Faked phone frame with a sample notification hovering over a blurred
/// workout screen. Every asset here is decorative — nothing wired up.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview();

  static const _appIconAsset = 'assets/branding/app_icon.png';
  static const _heroAsset = 'assets/branding/amy_kick_pose.png';
  static const _thumbAsset = 'assets/branding/amy_cutout_2.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Constrain the mockup so it always sits on-screen; on small
        // devices the outer Expanded gives us less room, and we scale down.
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final frameWidth = maxWidth.clamp(220.0, 320.0);
        final frameHeight = maxHeight.clamp(360.0, 520.0);
        return Center(
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: _PhoneFrame(
              child: _MockContent(
                scheme: scheme,
                iconAsset: _appIconAsset,
                heroAsset: _heroAsset,
                thumbAsset: _thumbAsset,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(38),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: ColoredBox(
          color: scheme.surface,
          child: child,
        ),
      ),
    );
  }
}

class _MockContent extends StatelessWidget {
  const _MockContent({
    required this.scheme,
    required this.iconAsset,
    required this.heroAsset,
    required this.thumbAsset,
  });

  final ColorScheme scheme;
  final String iconAsset;
  final String heroAsset;
  final String thumbAsset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    return Stack(
      children: [
        // Blurred workout screen behind the notification. Dimmed so the
        // notification bubble stays the focal point.
        Positioned.fill(
          child: Opacity(
            opacity: 0.55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '21 DAYS',
                        style: text.labelSmall?.copyWith(color: muted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: muted),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Edit',
                          style: text.labelSmall?.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Focus Area\nGoal',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Stage 1: Quick Slim Down',
                        style: text.labelSmall?.copyWith(color: muted),
                      ),
                      const Spacer(),
                      Text(
                        '25%',
                        style: text.labelSmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: 0.25,
                      minHeight: 4,
                      backgroundColor:
                          scheme.onSurface.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              heroAsset,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Band Power Break',
                                  style: text.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '4 mins · 10 kcal',
                                  style: text.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating notification card.
        Positioned(
          left: 8,
          right: 8,
          top: 78,
          child: _NotificationCard(
            iconAsset: iconAsset,
            thumbAsset: thumbAsset,
            scheme: scheme,
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.iconAsset,
    required this.thumbAsset,
    required this.scheme,
  });

  final String iconAsset;
  final String thumbAsset;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              iconAsset,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Time to Move!',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '2m',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Your personalized military drill awaits — let's crush "
                  "today's plan! 💪",
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              thumbAsset,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ],
      ),
    );
  }
}

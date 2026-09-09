import 'package:flutter/material.dart';

import 'onboarding_progress_bar.dart';

/// Chrome used by every step in an onboarding flow: back button + progress
/// bar on top, the step's body below, and an optional bottom CTA area.
///
/// Kept theme-agnostic — pulls the ground color from Scaffold's default (i.e.
/// the app theme's scaffoldBackgroundColor) unless [backgroundColor] is given.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.progress,
    this.showBack = true,
    this.backgroundColor,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  final Widget child;
  final VoidCallback? onBack;
  final double? progress;
  final bool showBack;
  final Color? backgroundColor;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    if (showBack)
                      _BackChevron(
                        onTap: onBack,
                        color: scheme.onSurface,
                      )
                    else
                      const SizedBox(width: 44),
                    const SizedBox(width: 12),
                    if (progress != null)
                      Expanded(child: OnboardingProgressBar(progress: progress!))
                    else
                      const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: child),
              if (bottom != null) ...[
                const SizedBox(height: 16),
                bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron({required this.onTap, required this.color});

  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(Icons.chevron_left_rounded, color: color, size: 30),
        ),
      ),
    );
  }
}

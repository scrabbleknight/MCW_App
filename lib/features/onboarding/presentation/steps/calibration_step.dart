import 'dart:async';

import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// Loading beat that fires the plan generator behind a progress spinner
/// while auto-rotating social-proof reviews below. Once both the spinner
/// hits 100% and the generator returns, [onReady] fires with the plan.
class CalibrationStep extends StatefulWidget {
  const CalibrationStep({
    super.key,
    required this.inputs,
    required this.onReady,
    this.minDuration = const Duration(seconds: 5),
  });

  final PlanInputs inputs;
  final ValueChanged<Plan> onReady;

  /// Minimum time the spinner is on-screen for. Prevents the "flash of
  /// finished loader" when the algorithm returns in a few ms.
  final Duration minDuration;

  @override
  State<CalibrationStep> createState() => _CalibrationStepState();
}

class _CalibrationStepState extends State<CalibrationStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<Plan> _planFuture;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    // Assign the controller BEFORE attaching listeners or starting the
    // animation. The status listener reads `_controller.status`, and if
    // `..forward()` synchronously notified during the cascade the `late
    // final` field would not be initialized yet (LateInitializationError).
    _controller =
        AnimationController(vsync: this, duration: widget.minDuration);
    _controller.addStatusListener(_maybeHandOff);
    _controller.forward();

    // Give the animator one frame before generating so the first paint isn't
    // blocked by the algorithm — this keeps the spinner visibly starting at
    // 0% even on slower devices.
    _planFuture = Future<Plan>.microtask(() => generatePlan(widget.inputs))
      ..then((_) => _maybeHandOff(null));
  }

  void _maybeHandOff(AnimationStatus? _) {
    if (_handedOff) return;
    if (_controller.status != AnimationStatus.completed) return;
    _planFuture.then((plan) {
      if (!mounted || _handedOff) return;
      _handedOff = true;
      widget.onReady(plan);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final value = _controller.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        backgroundColor:
                            scheme.onSurface.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Creating your personalized Calisthenics Workout Plan',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 36),
        Text(
          '65 million people',
          textAlign: TextAlign.center,
          style: text.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'have chosen Military Calisthenics Workout',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        // Fixed carousel height — reviews are short, so a taller card just
        // reads as empty space; cap it at ~200 so it never fills the
        // remaining screen space on tall phones.
        const SizedBox(height: 210, child: _ReviewCarousel()),
        const Spacer(),
      ],
    );
  }
}

// -------- Reviews --------------------------------------------------------

class _Review {
  const _Review({required this.name, required this.text});
  final String name;
  final String text;
}

/// Fake but plausible testimonials. Names skew female to match the audience,
/// tone stays casual. Swap for real testimonials once the app launches.
const _reviews = <_Review>[
  _Review(
    name: 'Priya',
    text:
        "Honestly the first plan I've stuck with. It scales to how I'm feeling "
        'that day and I actually look forward to the sessions now.',
  ),
  _Review(
    name: 'Sofia',
    text:
        'I was worried it would be too intense but the coach dialled it in for '
        "me. Lost 6 kg in two months and I'm sleeping better too.",
  ),
  _Review(
    name: 'Yasmin',
    text:
        'Being able to say "no jumping" during onboarding sold it for me — my '
        'knees hate impact and every workout still feels tough.',
  ),
  _Review(
    name: 'Chloe',
    text:
        'The 20-30 minute sessions fit around my kids. Small wins add up and '
        "I've noticed my posture change already.",
  ),
  _Review(
    name: 'Aisha',
    text:
        "Ex-army, so 'military' had to actually mean something — it does. The "
        'progression is spot on. Recommending to my whole running club.',
  ),
  _Review(
    name: 'Rachel',
    text:
        'The plan preview at the end made me trust it before I even started. '
        'Two weeks in and my clothes are fitting differently.',
  ),
  _Review(
    name: 'Marta',
    text:
        'I like that rest days are actually built in. No guilt-tripping when '
        "I don't work out — the plan just picks up the next day.",
  ),
  _Review(
    name: 'Lena',
    text:
        'Simple, no gym, no equipment. Perfect for the road — I travel every '
        "week for work and I've kept the streak going.",
  ),
];

class _ReviewCarousel extends StatefulWidget {
  const _ReviewCarousel();

  @override
  State<_ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<_ReviewCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: 0.86,
      initialPage: 0,
    );
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % _reviews.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: _reviews.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) => _ReviewCard(review: _reviews[i]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final _Review review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.15),
                    child: Text(
                      review.name.substring(0, 1),
                      style: text.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      review.name,
                      style: text.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (_) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1),
                        child: Icon(Icons.star_rounded,
                            color: Color(0xFFE7A83A), size: 17),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                review.text,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.9),
                  height: 1.4,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


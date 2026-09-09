import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum Trainer { hailey, gemma, amy }

extension TrainerAssets on Trainer {
  /// Full-body character cutout for hero placements.
  String get cutoutAsset => switch (this) {
        Trainer.hailey => 'assets/branding/hailey_cutout_1.png',
        Trainer.gemma => 'assets/branding/gemma_cutout_1.png',
        Trainer.amy => 'assets/branding/amy_cutout_1.png',
      };

  /// Portrait used inside the trainer-pick cards.
  String get portraitAsset => switch (this) {
        Trainer.hailey => 'assets/branding/hailey_trainer_1.png',
        Trainer.gemma => 'assets/branding/gemma_trainer_2.png',
        Trainer.amy => 'assets/branding/amy_trainer_3.png',
      };

  /// Head-and-shoulders portrait used for the small circular avatar chip on
  /// downstream screens (chat rows, headers).
  String get avatarAsset => switch (this) {
        Trainer.hailey => 'assets/branding/hailey_cutout_2.png',
        Trainer.gemma => 'assets/branding/gemma_cutout_2.png',
        Trainer.amy => 'assets/branding/amy_cutout_2.png',
      };

  String get displayName => switch (this) {
        Trainer.hailey => 'Hailey',
        Trainer.gemma => 'Gemma',
        Trainer.amy => 'Amy',
      };
}

/// One trainer's card content. Kept as a value type so the roster is a plain
/// list at the top of the widget and easy to reorder or extend.
class _TrainerCard {
  const _TrainerCard({required this.value, required this.imageAsset});

  final Trainer value;
  final String imageAsset;
}

const _roster = <_TrainerCard>[
  _TrainerCard(
    value: Trainer.hailey,
    imageAsset: 'assets/branding/hailey_trainer_1.png',
  ),
  _TrainerCard(
    value: Trainer.gemma,
    imageAsset: 'assets/branding/gemma_trainer_2.png',
  ),
  _TrainerCard(
    value: Trainer.amy,
    imageAsset: 'assets/branding/amy_trainer_3.png',
  ),
];

/// Swipeable trainer picker. Card in view is the selection; PICK confirms.
class TrainerPickStep extends StatefulWidget {
  const TrainerPickStep({
    super.key,
    required this.initial,
    required this.onCompleted,
  });

  final Trainer? initial;
  final ValueChanged<Trainer> onCompleted;

  @override
  State<TrainerPickStep> createState() => _TrainerPickStepState();
}

class _TrainerPickStepState extends State<TrainerPickStep> {
  static const _goldTop = Color(0xFFF6E7A9);
  static const _goldBottom = Color(0xFFB68A2A);

  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initial == null
        ? 0
        : _roster.indexWhere((c) => c.value == widget.initial);
    if (_index < 0) _index = 0;
    _controller = PageController(
      initialPage: _index,
      viewportFraction: 0.82,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_goldTop, _goldBottom],
          ).createShader(rect),
          child: Text(
            'RECRUITS, ASSEMBLE!',
            textAlign: TextAlign.center,
            style: text.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Pick Your Lead For Your Military Calisthenics Mission.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _roster.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _TrainerCardView(
              card: _roster[i],
              active: i == _index,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You can switch your lead later 💪',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryCta(
          label: 'PICK',
          trailingIcon: null,
          onPressed: () => widget.onCompleted(_roster[_index].value),
        ),
      ],
    );
  }
}

class _TrainerCardView extends StatelessWidget {
  const _TrainerCardView({required this.card, required this.active});

  final _TrainerCard card;
  final bool active;

  static const _goldTop = Color(0xFFF6E7A9);
  static const _goldBottom = Color(0xFFB68A2A);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: active ? 1 : 0.94,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_goldTop, _goldBottom, _goldTop],
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: _goldBottom.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Image.asset(
              card.imageAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
      ),
    );
  }
}


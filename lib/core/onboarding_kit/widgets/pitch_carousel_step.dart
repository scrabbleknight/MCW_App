import 'dart:async';

import 'package:flutter/material.dart';

import 'primary_cta.dart';

/// One slide inside a [PitchCarouselStep] — a hero photo card with a short
/// benefit heading + supporting line rendered as an overlay at the bottom.
class PitchSlide {
  const PitchSlide({
    required this.imageAsset,
    required this.heading,
    required this.body,
  });

  final String imageAsset;
  final String heading;
  final String body;
}

/// Onboarding "why this works" carousel — one shared title on top, a
/// pageable stack of hero cards in the middle, page-dot indicator, and a
/// primary CTA at the bottom that advances between slides and finishes the
/// step on the last one.
///
/// Zero project-specific imports — colours come from the current theme, all
/// copy from parameters, so any future app can drop this in with a new slide
/// list.
class PitchCarouselStep extends StatefulWidget {
  const PitchCarouselStep({
    super.key,
    required this.title,
    required this.slides,
    required this.onCompleted,
    this.ctaLabel = 'CONTINUE',
    this.autoAdvanceInterval = const Duration(seconds: 3),
  });

  final String title;
  final List<PitchSlide> slides;
  final VoidCallback onCompleted;
  final String ctaLabel;

  /// Time each slide lingers before the carousel animates to the next one.
  /// The rotation loops (last → first). Manual swipes don't stop it.
  final Duration autoAdvanceInterval;

  @override
  State<PitchCarouselStep> createState() => _PitchCarouselStepState();
}

class _PitchCarouselStepState extends State<PitchCarouselStep> {
  final PageController _controller = PageController();
  int _index = 0;
  Timer? _autoAdvance;

  @override
  void initState() {
    super.initState();
    if (widget.slides.length > 1) {
      _autoAdvance = Timer.periodic(widget.autoAdvanceInterval, (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % widget.slides.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // CONTINUE always closes the step — it is a shortcut past the whole
  // pitch, not an advance within the carousel.
  void _onCta() => widget.onCompleted();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _SlideCard(slide: widget.slides[i]),
          ),
        ),
        const SizedBox(height: 16),
        _Dots(count: widget.slides.length, activeIndex: _index),
        const SizedBox(height: 16),
        PrimaryCta(label: widget.ctaLabel, onPressed: _onCta),
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});

  final PitchSlide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                slide.imageAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stack) =>
                    ColoredBox(color: scheme.surface),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        scheme.surface.withValues(alpha: 0.75),
                        scheme.surface.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.heading,
                          style: text.titleLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slide.body,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.85),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            height: 8,
            width: i == activeIndex ? 24 : 8,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'primary_cta.dart';

/// One testimonial card in a [TestimonialCarouselStep].
///
/// [imageAsset] is expected to be a pre-composited "before / after" image
/// (two shots side-by-side in a single file); this widget just overlays
/// "Day X" chips on the corners of it.
class Testimonial {
  const Testimonial({
    required this.imageAsset,
    required this.title,
    required this.body,
    this.rating = 5,
    this.beforeLabel = 'Day 1',
    required this.afterLabel,
  });

  final String imageAsset;
  final String title;
  final String body;
  final int rating;
  final String beforeLabel;
  final String afterLabel;
}

/// Onboarding "social proof" carousel — shared title on top, an auto-cycling
/// stack of testimonial cards (before/after image with Day chips + review
/// text underneath), and a CONTINUE CTA that always advances the outer flow.
///
/// Colour-agnostic; drop into any product's onboarding by swapping the
/// [testimonials] list.
class TestimonialCarouselStep extends StatefulWidget {
  const TestimonialCarouselStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.testimonials,
    required this.onCompleted,
    this.ctaLabel = 'CONTINUE',
    this.autoAdvanceInterval = const Duration(seconds: 4),
  });

  final String title;
  final String subtitle;
  final List<Testimonial> testimonials;
  final VoidCallback onCompleted;
  final String ctaLabel;
  final Duration autoAdvanceInterval;

  @override
  State<TestimonialCarouselStep> createState() =>
      _TestimonialCarouselStepState();
}

class _TestimonialCarouselStepState extends State<TestimonialCarouselStep> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  int _index = 0;
  Timer? _autoAdvance;

  @override
  void initState() {
    super.initState();
    if (widget.testimonials.length > 1) {
      _autoAdvance = Timer.periodic(widget.autoAdvanceInterval, (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % widget.testimonials.length;
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.subtitle,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.72),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.testimonials.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) =>
                _TestimonialCard(testimonial: widget.testimonials[i]),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryCta(label: widget.ctaLabel, onPressed: widget.onCompleted),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});

  final Testimonial testimonial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.4,
            ),
          ),
          // Image flexes: takes whatever height remains after the text sits
          // at its natural size. Prevents overflow on short screens and
          // fills bigger cards on taller devices — no hard-coded ratios.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.asset(
                  testimonial.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      ColoredBox(color: scheme.surface),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      testimonial.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StarRow(count: testimonial.rating),
                    const SizedBox(height: 10),
                    Text(
                      testimonial.body,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              i < count ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFF5B301),
              size: size,
            ),
          ),
      ],
    );
  }
}

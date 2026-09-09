import 'package:flutter/material.dart';

import 'primary_cta.dart';

/// Informational page — a declarative statement + one or two supporting
/// paragraphs + a centered hero image card + a CONTINUE CTA. No user input
/// beyond tapping Continue.
class StatementImageSlide extends StatelessWidget {
  const StatementImageSlide({
    super.key,
    required this.title,
    required this.paragraphs,
    required this.imageAsset,
    required this.onContinue,
    this.ctaLabel = 'CONTINUE',
  });

  final String title;
  final List<String> paragraphs;
  final String imageAsset;
  final VoidCallback onContinue;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < paragraphs.length; i++) ...[
          Text(
            paragraphs[i],
            style: text.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          if (i < paragraphs.length - 1) const SizedBox(height: 14),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    ColoredBox(color: scheme.surface),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryCta(label: ctaLabel, onPressed: onContinue),
      ],
    );
  }
}

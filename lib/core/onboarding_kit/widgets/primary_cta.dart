import 'package:flutter/material.dart';

/// Full-width primary call-to-action used at the bottom of onboarding slides.
///
/// Reads its color from the app theme's `filledButtonTheme` — so a future app
/// only has to redefine that theme block to reskin every CTA in the flow.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon = Icons.arrow_forward_rounded,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            if (trailingIcon != null) ...[
              const SizedBox(width: 10),
              Icon(trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

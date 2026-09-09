import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum TypicalDay { mostlySitting, activeBreaks, onFeetAllDay }

/// Text-only single choice — daily activity baseline. Auto-advances on tap.
class TypicalDayStep extends StatelessWidget {
  const TypicalDayStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final TypicalDay? selected;
  final ValueChanged<TypicalDay> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<TypicalDay>(
      question: 'How would you describe your typical day?',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: TypicalDay.mostlySitting,
          label: 'I spend most of the day sitting',
        ),
        OnboardingOption(
          value: TypicalDay.activeBreaks,
          label: 'I take active breaks',
        ),
        OnboardingOption(
          value: TypicalDay.onFeetAllDay,
          label: "I'm on my feet all day long",
        ),
      ],
    );
  }
}

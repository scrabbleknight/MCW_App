import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum WeightGainEvent {
  workPressure,
  busyFamilyLife,
  divorceOrBreakup,
  slowerMetabolism,
  none,
}

/// Multi-select — life events that have led to weight gain in recent years.
class WeightGainEventsStep extends StatelessWidget {
  const WeightGainEventsStep({
    super.key,
    required this.initialSelection,
    required this.onCompleted,
  });

  final Set<WeightGainEvent> initialSelection;
  final ValueChanged<Set<WeightGainEvent>> onCompleted;

  @override
  Widget build(BuildContext context) {
    return MultiChoiceSlide<WeightGainEvent>(
      question: 'Have any of the following events led to weight gain in the last few years?',
      initialSelection: initialSelection,
      onCompleted: onCompleted,
      minSelection: 1,
      options: const [
        OnboardingOption(
          value: WeightGainEvent.workPressure,
          label: 'Work pressure',
        ),
        OnboardingOption(
          value: WeightGainEvent.busyFamilyLife,
          label: 'Busy family life',
        ),
        OnboardingOption(
          value: WeightGainEvent.divorceOrBreakup,
          label: 'Divorce or breakup',
        ),
        OnboardingOption(
          value: WeightGainEvent.slowerMetabolism,
          label: 'Slower metabolism due to aging',
        ),
        OnboardingOption(
          value: WeightGainEvent.none,
          label: 'None of the above',
        ),
      ],
    );
  }
}

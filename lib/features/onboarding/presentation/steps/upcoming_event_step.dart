import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum UpcomingEvent { vacation, wedding, holiday, sportingEvent, reunion, none }

/// Single-select — an event to aim for. Used to set the plan's deadline and
/// pacing rather than to change the workout itself.
class UpcomingEventStep extends StatelessWidget {
  const UpcomingEventStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final UpcomingEvent? selected;
  final ValueChanged<UpcomingEvent> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<UpcomingEvent>(
      question: 'Do you have an important event coming up?',
      helper: "You're more likely to reach your goal when you have "
          'something to aim for',
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(value: UpcomingEvent.vacation, label: 'Vacation'),
        OnboardingOption(value: UpcomingEvent.wedding, label: 'Wedding'),
        OnboardingOption(value: UpcomingEvent.holiday, label: 'Holiday'),
        OnboardingOption(
          value: UpcomingEvent.sportingEvent,
          label: 'Sporting event',
        ),
        OnboardingOption(value: UpcomingEvent.reunion, label: 'Reunion'),
        OnboardingOption(value: UpcomingEvent.none, label: 'Nope'),
      ],
    );
  }
}

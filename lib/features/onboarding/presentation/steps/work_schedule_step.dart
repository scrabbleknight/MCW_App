import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum WorkSchedule { regularDaytime, flexible, nightShift, retiredOrOffwork }

/// Text-only single choice — working hours pattern. Drives when-to-train
/// recommendations later.
class WorkScheduleStep extends StatelessWidget {
  const WorkScheduleStep({
    super.key,
    required this.selected,
    required this.onAnswered,
  });

  final WorkSchedule? selected;
  final ValueChanged<WorkSchedule> onAnswered;

  @override
  Widget build(BuildContext context) {
    return SingleChoiceSlide<WorkSchedule>(
      question: "What's your work schedule like?",
      selectedValue: selected,
      onSelected: onAnswered,
      options: const [
        OnboardingOption(
          value: WorkSchedule.regularDaytime,
          label: 'Regular daytime hours',
        ),
        OnboardingOption(
          value: WorkSchedule.flexible,
          label: 'My hours are flexible',
        ),
        OnboardingOption(
          value: WorkSchedule.nightShift,
          label: 'Night shifts',
        ),
        OnboardingOption(
          value: WorkSchedule.retiredOrOffwork,
          label: "I'm retired / not working right now",
        ),
      ],
    );
  }
}

import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

String? missionDayImageAsset(PlanDay day) {
  if (day.dayIndex < 1 || day.dayIndex > 21) return null;
  return 'assets/branding/day${day.dayIndex}.png';
}

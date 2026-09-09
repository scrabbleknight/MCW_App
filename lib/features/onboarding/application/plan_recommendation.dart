import 'package:military_calisthenics_women/features/onboarding/presentation/steps/age_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/current_weight_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/exercise_frequency_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/goal_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/height_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_duration_step.dart';

/// BMI categories per CDC adult reference ranges.
enum BmiCategory { underweight, normal, overweight, obese }

extension BmiCategoryLabel on BmiCategory {
  String get label => switch (this) {
        BmiCategory.underweight => 'Underweight',
        BmiCategory.normal => 'Normal',
        BmiCategory.overweight => 'Overweight',
        BmiCategory.obese => 'Obese',
      };
}

/// Aggregate readout shown on the wellness-profile step. Derived from the
/// user's answers rather than stored on the controller — the plan algorithm
/// lives here and can grow without any wiring changes.
class PlanRecommendation {
  const PlanRecommendation({
    required this.bmi,
    required this.category,
    required this.workoutArea,
    required this.durationLabel,
    required this.caloriesPerDay,
    required this.description,
  });

  final double bmi;
  final BmiCategory category;
  final String workoutArea;
  final String durationLabel;
  final int caloriesPerDay;
  final String description;

  /// Position of the BMI within the visualised [15, 40] band, clamped to
  /// 0.0..1.0. Drives the indicator triangle on the wellness-profile bar.
  double get barPosition {
    const min = 15.0;
    const max = 40.0;
    final t = (bmi - min) / (max - min);
    if (t.isNaN) return 0.5;
    return t.clamp(0.0, 1.0);
  }
}

/// Builds a [PlanRecommendation] from onboarding answers. Requires at least
/// [currentWeight] and [height]; other inputs refine the plan but have safe
/// defaults so the readout is always renderable.
PlanRecommendation buildPlanRecommendation({
  required WeightAnswer currentWeight,
  required HeightAnswer height,
  AgeBand? ageBand,
  ExerciseFrequency? exerciseFrequency,
  FitnessGoal? goal,
  WorkoutDuration? duration,
}) {
  final heightM = height.cm / 100.0;
  final bmi = currentWeight.kg / (heightM * heightM);
  final category = _categorise(bmi);
  final calories = _dailyCalorieTarget(
    weightKg: currentWeight.kg,
    heightCm: height.cm,
    ageBand: ageBand,
    frequency: exerciseFrequency,
    goal: goal,
  );
  return PlanRecommendation(
    bmi: double.parse(bmi.toStringAsFixed(1)),
    category: category,
    workoutArea: _workoutAreaFor(goal),
    durationLabel: _durationLabelFor(duration),
    caloriesPerDay: calories,
    description:
        'Your current BMI is within the ${category.label} range. The data are '
        'for reference only. Please analyze according to the specific '
        'physical examination report.',
  );
}

BmiCategory _categorise(double bmi) {
  if (bmi < 18.5) return BmiCategory.underweight;
  if (bmi < 25) return BmiCategory.normal;
  if (bmi < 30) return BmiCategory.overweight;
  return BmiCategory.obese;
}

String _workoutAreaFor(FitnessGoal? goal) => switch (goal) {
      FitnessGoal.buildStrength => 'Upper body + core',
      FitnessGoal.loseWeight => 'Full body',
      FitnessGoal.recomp => 'Full body',
      FitnessGoal.maintainAndFit => 'Full body',
      null => 'Full body',
    };

String _durationLabelFor(WorkoutDuration? duration) => switch (duration) {
      WorkoutDuration.under10 => 'Under 10 mins',
      WorkoutDuration.tenToFifteen => '10-15 mins',
      WorkoutDuration.fifteenToTwenty => '15-20 mins',
      WorkoutDuration.twentyToThirty => '20-30 mins',
      null => '15-20 mins',
    };

/// Recommended daily caloric intake target using the Mifflin-St Jeor RMR
/// equation (female coefficients), scaled to TDEE by activity level, then
/// nudged by the user's fitness goal. Result is rounded to the nearest 10
/// kcal and clamped to a safe floor of 1200 kcal/day.
int _dailyCalorieTarget({
  required double weightKg,
  required double heightCm,
  required AgeBand? ageBand,
  required ExerciseFrequency? frequency,
  required FitnessGoal? goal,
}) {
  final age = _ageForBand(ageBand);
  // Mifflin-St Jeor RMR (women): 10W + 6.25H - 5A - 161.
  final rmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  final tdee = rmr * _activityMultiplier(frequency);
  final adjusted = tdee + _goalAdjustment(goal);
  final clamped = adjusted < 1200 ? 1200.0 : adjusted;
  return (clamped / 10).round() * 10;
}

double _ageForBand(AgeBand? band) => switch (band) {
      AgeBand.under18 => 17,
      AgeBand.from18to24 => 21,
      AgeBand.from25to34 => 29,
      AgeBand.from35to44 => 39,
      AgeBand.from45to54 => 49,
      AgeBand.over55 => 60,
      // Sensible default if the age step somehow wasn't answered.
      null => 30,
    };

double _activityMultiplier(ExerciseFrequency? frequency) => switch (frequency) {
      ExerciseFrequency.daily => 1.55,
      ExerciseFrequency.weekly => 1.375,
      ExerciseFrequency.monthly => 1.25,
      ExerciseFrequency.never => 1.2,
      null => 1.375,
    };

double _goalAdjustment(FitnessGoal? goal) => switch (goal) {
      // 500 kcal/day deficit ≈ ~1 lb / 0.45 kg loss per week — the standard
      // sustainable target.
      FitnessGoal.loseWeight => -500,
      FitnessGoal.recomp => -300,
      FitnessGoal.buildStrength => 200,
      FitnessGoal.maintainAndFit => 0,
      null => 0,
    };

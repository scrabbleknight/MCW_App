import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/age_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/diet_type_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/eating_habits_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/exercise_frequency_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/fitness_level_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/goal_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/main_reason_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/upcoming_event_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_duration_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_preferences_step.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for [PlanInputs] so the 21-day plan can be regenerated after a
/// cold restart. We store the inputs (small, enum-only JSON) rather than the
/// generated [Plan] itself, then re-run [generatePlan] on load — cheaper and
/// keeps future generator tweaks in play without a migration.
class PlanInputsStore {
  static const _key = 'plan_inputs_v1';

  Future<void> save(PlanInputs inputs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_encode(inputs)));
    } catch (error) {
      debugPrint('PlanInputsStore: save failed — $error');
    }
  }

  Future<PlanInputs?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _decode(map);
    } catch (error) {
      debugPrint('PlanInputsStore: load failed — $error');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (error) {
      debugPrint('PlanInputsStore: clear failed — $error');
    }
  }

  Map<String, dynamic> _encode(PlanInputs i) => <String, dynamic>{
        'weightKg': i.weightKg,
        'heightCm': i.heightCm,
        'ageBand': i.ageBand?.name,
        'goal': i.goal?.name,
        'fitnessLevel': i.fitnessLevel?.name,
        'exerciseFrequency': i.exerciseFrequency?.name,
        'workoutDuration': i.workoutDuration?.name,
        'workoutPreference': i.workoutPreference?.name,
        'trainer': i.trainer?.name,
        'mainReason': i.mainReason?.name,
        'upcomingEvent': i.upcomingEvent?.name,
        'dietType': i.dietType?.name,
        'eatingHabits':
            i.eatingHabits?.map((h) => h.name).toList(growable: false),
        'dailyCalorieTarget': i.dailyCalorieTarget,
      };

  PlanInputs _decode(Map<String, dynamic> m) => PlanInputs(
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        heightCm: (m['heightCm'] as num?)?.toDouble(),
        ageBand: _byName(AgeBand.values, m['ageBand']),
        goal: _byName(FitnessGoal.values, m['goal']),
        fitnessLevel: _byName(FitnessLevel.values, m['fitnessLevel']),
        exerciseFrequency:
            _byName(ExerciseFrequency.values, m['exerciseFrequency']),
        workoutDuration:
            _byName(WorkoutDuration.values, m['workoutDuration']),
        workoutPreference:
            _byName(WorkoutPreference.values, m['workoutPreference']),
        trainer: _byName(Trainer.values, m['trainer']),
        mainReason: _byName(MainReason.values, m['mainReason']),
        upcomingEvent: _byName(UpcomingEvent.values, m['upcomingEvent']),
        dietType: _byName(DietType.values, m['dietType']),
        eatingHabits: (m['eatingHabits'] as List?)
            ?.map((n) => _byName(EatingHabit.values, n))
            .whereType<EatingHabit>()
            .toSet(),
        dailyCalorieTarget: m['dailyCalorieTarget'] as int?,
      );

  T? _byName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

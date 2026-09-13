import 'dart:math';

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
import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise_catalogue.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// Bundled inputs to [generatePlan] — a plain value carrier so the callsite
/// (the calibration step) can build one from the onboarding controller
/// without leaking Provider into the algorithm.
class PlanInputs {
  const PlanInputs({
    this.weightKg,
    this.heightCm,
    this.ageBand,
    this.goal,
    this.fitnessLevel,
    this.exerciseFrequency,
    this.workoutDuration,
    this.workoutPreference,
    this.trainer,
    this.mainReason,
    this.upcomingEvent,
    this.dietType,
    this.eatingHabits,
    this.dailyCalorieTarget,
  });

  final double? weightKg;
  final double? heightCm;
  final AgeBand? ageBand;
  final FitnessGoal? goal;
  final FitnessLevel? fitnessLevel;
  final ExerciseFrequency? exerciseFrequency;
  final WorkoutDuration? workoutDuration;
  final WorkoutPreference? workoutPreference;
  final Trainer? trainer;
  final MainReason? mainReason;
  final UpcomingEvent? upcomingEvent;
  final DietType? dietType;
  final Set<EatingHabit>? eatingHabits;
  final int? dailyCalorieTarget;

  PlanInputs copyWith({
    double? weightKg,
    double? heightCm,
    AgeBand? ageBand,
    FitnessGoal? goal,
    FitnessLevel? fitnessLevel,
    ExerciseFrequency? exerciseFrequency,
    WorkoutDuration? workoutDuration,
    WorkoutPreference? workoutPreference,
    Trainer? trainer,
    MainReason? mainReason,
    UpcomingEvent? upcomingEvent,
    DietType? dietType,
    Set<EatingHabit>? eatingHabits,
    int? dailyCalorieTarget,
  }) {
    return PlanInputs(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      ageBand: ageBand ?? this.ageBand,
      goal: goal ?? this.goal,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      exerciseFrequency: exerciseFrequency ?? this.exerciseFrequency,
      workoutDuration: workoutDuration ?? this.workoutDuration,
      workoutPreference: workoutPreference ?? this.workoutPreference,
      trainer: trainer ?? this.trainer,
      mainReason: mainReason ?? this.mainReason,
      upcomingEvent: upcomingEvent ?? this.upcomingEvent,
      dietType: dietType ?? this.dietType,
      eatingHabits: eatingHabits ?? this.eatingHabits,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
    );
  }
}

/// 21-day mission builder. Every day gets:
///   - 2 warm-up exercises (mobility / activation)
///   - 7 main exercises (balanced across the day's focus)
///   - 2 cool-down exercises (static holds / breath)
///
/// The plan is deterministic per user profile: same answers → same 21 days.
/// Exercises can and do repeat across days, but within any one day nothing
/// appears twice, and consecutive days try not to open with the same warm-up.
Plan generatePlan(PlanInputs inputs) {
  final rng = Random(_seedFor(inputs));

  final pool = _filterPool(inputs.workoutPreference);
  // Only exercises with supplied media can be scheduled. Some of those use
  // legacy ids (for example Push-Up and Swimmers), so phase membership is
  // explicit rather than inferred from an id prefix.
  final warmupPool = pool
      .where((exercise) => _warmupExerciseIds.contains(exercise.id))
      .toList(growable: false);
  final cooldownPool = pool
      .where((exercise) => _cooldownExerciseIds.contains(exercise.id))
      .toList(growable: false);
  final mainPool = pool
      .where((exercise) => _mainExerciseIds.contains(exercise.id))
      .toList(growable: false);

  final shape = _sessionShape(inputs);
  final tone = _tone(inputs);
  final stages = _stagesFor(inputs.goal);

  final days = <PlanDay>[];
  String? previousWarmupOpener;

  for (var d = 1; d <= 21; d++) {
    final stageIndex = ((d - 1) ~/ 7); // 0..2
    final intensity = _intensityForDay(d);
    final focus = _rotation[(d - 1) % _rotation.length];

    final warmupPicks =
        _warmupsForDay(
          day: d,
          focus: focus,
          pool: warmupPool,
          rng: rng,
          avoidFirstId: previousWarmupOpener,
        ) ??
        _pickWarmups(
          pool: warmupPool,
          rng: rng,
          avoidFirstId: previousWarmupOpener,
        );
    if (warmupPicks.isNotEmpty) previousWarmupOpener = warmupPicks.first.id;

    final mainPicks = _mainExercisesForDay(
      day: d,
      pool: mainPool,
      focus: focus,
      goal: inputs.goal,
      rng: rng,
      count: 7,
    );

    final cooldownPicks =
        _cooldownsForDay(day: d, focus: focus, pool: cooldownPool, rng: rng) ??
        _pickCooldowns(pool: cooldownPool, rng: rng);

    days.add(
      PlanDay(
        dayIndex: d,
        title: _dayTitles[focus] ?? 'Total Body',
        warmup: warmupPicks
            .map((ex) => _toBlock(ex, PlanPhase.warmup, shape, intensity))
            .toList(growable: false),
        main: mainPicks
            .map((ex) => _toBlock(ex, PlanPhase.main, shape, intensity))
            .toList(growable: false),
        cooldown: cooldownPicks
            .map((ex) => _toBlock(ex, PlanPhase.cooldown, shape, intensity))
            .toList(growable: false),
      ),
    );
    // stageIndex is used only implicitly (index / 7); kept as a sanity check
    // that days align to their stage in future logs.
    assert(stageIndex >= 0 && stageIndex < stages.length);
  }

  return Plan(
    durationDays: 21,
    dailyCalorieTarget: inputs.dailyCalorieTarget ?? 1600,
    focusAreaLabel: _focusLabel(inputs.goal),
    sessionDurationLabel: _durationLabel(inputs.workoutDuration),
    title: _planTitle(inputs.goal),
    stages: stages,
    days: days,
    tone: tone,
  );
}

// ---------------------------------------------------------------------------
// Pool filtering
// ---------------------------------------------------------------------------

List<Exercise> _filterPool(WorkoutPreference? pref) {
  return exerciseCatalogue
      .where((ex) {
        switch (pref) {
          case WorkoutPreference.allStanding:
            return ex.position == ExercisePosition.standing;
          case WorkoutPreference.noSquat:
            return !ex.movements.contains(ExerciseMovement.squat);
          case WorkoutPreference.noJumping:
            return !ex.highImpact;
          case WorkoutPreference.noProne:
            return ex.position != ExercisePosition.prone;
          case WorkoutPreference.noKneeling:
            return ex.position != ExercisePosition.kneeling &&
                ex.position != ExercisePosition.bearStance;
          case WorkoutPreference.noPreferences:
          case null:
            return true;
        }
      })
      .toList(growable: false);
}

// ---------------------------------------------------------------------------
// Session shape (per-block prescription — sets / rest / volume multiplier)
// ---------------------------------------------------------------------------

class _SessionShape {
  const _SessionShape({
    required this.warmupSets,
    required this.mainSets,
    required this.cooldownSets,
    required this.restBetweenSets,
    required this.intensityMultiplier,
  });

  final int warmupSets;
  final int mainSets;
  final int cooldownSets;
  final int restBetweenSets;

  /// Multiplied into each exercise's [Exercise.baseAmount]. Base value is
  /// tuned for "intermediate" level; beginners drop, advanced climb.
  final double intensityMultiplier;
}

_SessionShape _sessionShape(PlanInputs inputs) {
  final mainSets = switch (inputs.fitnessLevel) {
    FitnessLevel.newbie => 1,
    FitnessLevel.beginner => 2,
    FitnessLevel.intermediate => 2,
    FitnessLevel.advanced => 3,
    null => 2,
  };
  final rest = switch (inputs.fitnessLevel) {
    FitnessLevel.newbie => 45,
    FitnessLevel.beginner => 40,
    FitnessLevel.intermediate => 30,
    FitnessLevel.advanced => 25,
    null => 35,
  };
  var mult = switch (inputs.fitnessLevel) {
    FitnessLevel.newbie => 0.6,
    FitnessLevel.beginner => 0.75,
    FitnessLevel.intermediate => 1.0,
    FitnessLevel.advanced => 1.2,
    null => 0.85,
  };
  mult *= switch (inputs.ageBand) {
    AgeBand.under18 => 0.95,
    AgeBand.from18to24 => 1.0,
    AgeBand.from25to34 => 1.0,
    AgeBand.from35to44 => 0.95,
    AgeBand.from45to54 => 0.9,
    AgeBand.over55 => 0.8,
    null => 0.95,
  };
  return _SessionShape(
    warmupSets: 1,
    mainSets: mainSets,
    cooldownSets: 1,
    restBetweenSets: rest,
    intensityMultiplier: mult,
  );
}

// ---------------------------------------------------------------------------
// Stages (3 x 7 days)
// ---------------------------------------------------------------------------

List<PlanStage> _stagesFor(FitnessGoal? goal) {
  final loseWeight = goal == FitnessGoal.loseWeight;
  return [
    PlanStage(
      index: 1,
      title: 'Stage 1: Activate Your Body',
      subtitle: 'Wake the movement patterns and lock in the daily habit.',
      dayIndices: List.generate(7, (i) => i + 1),
    ),
    PlanStage(
      index: 2,
      title: loseWeight ? 'Stage 2: Fat Burn Blast' : 'Stage 2: Build the Base',
      subtitle: 'Turn the volume up — stronger reps, tighter transitions.',
      dayIndices: List.generate(7, (i) => i + 8),
    ),
    PlanStage(
      index: 3,
      title: 'Stage 3: Body Sculpt',
      subtitle: 'Peak week — hardest sessions, cleanest form.',
      dayIndices: List.generate(7, (i) => i + 15),
    ),
  ];
}

/// Progresses linearly from 0.9 (day 1) to 1.15 (day 21).
double _intensityForDay(int day) {
  final t = (day - 1) / 20.0;
  return 0.9 + t * 0.25;
}

// ---------------------------------------------------------------------------
// Daily focus rotation — 7 slots, so the pattern repeats each stage-week.
// ---------------------------------------------------------------------------

enum _DayFocus {
  upperCore,
  lowerGlute,
  fullBodyCardio,
  coreMobility,
  totalBody,
}

const _rotation = <_DayFocus>[
  _DayFocus.totalBody,
  _DayFocus.lowerGlute,
  _DayFocus.upperCore,
  _DayFocus.fullBodyCardio,
  _DayFocus.lowerGlute,
  _DayFocus.upperCore,
  _DayFocus.coreMobility,
];

const _dayTitles = <_DayFocus, String>{
  _DayFocus.upperCore: 'Upper + Core',
  _DayFocus.lowerGlute: 'Lower + Glutes',
  _DayFocus.fullBodyCardio: 'Full Body Cardio',
  _DayFocus.coreMobility: 'Core & Mobility',
  _DayFocus.totalBody: 'Total Body Tone',
};

/// The complete media-backed library supplied for the mission. Keeping these
/// phase allow-lists separate prevents a fallback from silently introducing an
/// exercise that the app cannot demonstrate.
const _warmupExerciseIds = <String>{
  'wu_cross_toe_touch',
  'wu_high_knees_arm_drive',
  'wu_standing_trunk_rotation',
  'wu_standing_core_brace_march',
  'wu_arm_swings',
  'wu_front_to_side_arm_raises',
  'wu_standing_scapular_retraction',
  'wu_leg_swing_front_back_right',
  'wu_leg_swing_front_back_left',
  'wu_squat_to_stand',
  'stand_arm_circles',
  'wu_wide_toe_touches',
  'wu_shoulder_circles',
  'wu_walking_side_high_knee',
  'wu_side_to_side_squat_hold',
  'wu_toe_touch_side_lunges',
  'stand_hip_circles',
  'wu_reach_and_twists',
  'wu_small_arm_circles',
  'wu_wide_stance_3_point_reach',
  'wu_overhead_press_wide_steps',
  'wu_chest_claps_calf_raises',
  'wu_arm_cross_with_steps',
  'wu_side_step_arm_rainbows',
  'prone_swimmers',
  'wu_squat_reach_jacks',
  'wu_wide_step_twist',
  'wu_up_straight_punches',
  'wu_bent_over_wing_flys',
  'wu_skaters_double_steps',
  'wu_alternate_leg_reaches',
  'wu_clapping_steps',
  'wu_big_arm_circles',
};

const _mainExerciseIds = <String>{
  'main_standing_arm_punches',
  'main_standing_triceps_kickback',
  'main_lateral_lunge_left',
  'main_lateral_lunge_right',
  'knee_bird_dog',
  'main_knee_plank_hold',
  'main_prone_cobra',
  'prone_pushup',
  'main_plank_shoulder_tap',
  'main_scapular_pushup',
  'main_prone_w_activation',
  'main_self_resisted_biceps_curl_left',
  'main_self_resisted_biceps_curl_right',
  'main_mountain_climber',
  'main_plank_hold',
  'main_bent_knee_dead_bug',
  'main_bent_knee_leg_raise',
  'main_standing_oblique_crunch',
  'main_seated_knee_tuck',
  'squat_bodyweight',
  'sup_glute_bridge',
  'main_standing_glute_kickback_left',
  'main_standing_glute_kickback_right',
  'main_fire_hydrant_left',
  'main_fire_hydrant_right',
  'main_standing_calf_raise',
  'main_static_lunge_hold_left',
  'main_static_lunge_hold_right',
  'main_donkey_kick_left',
  'main_donkey_kick_right',
  'main_knee_pushup',
  'main_diamond_pushup',
  'main_pike_pushup',
  'main_side_lunge_and_reach',
  'main_squat_heel_tap_jump',
  'main_seated_twist_arm_opening',
  'main_bicycle_kicks',
  'main_ab_crunch_leg_extension',
  'main_single_leg_v_ups',
  'main_extended_knee_in_outs',
  'sup_russian_twist',
  'main_hip_thrusts',
  'main_crab_reach',
  'main_leg_scissors',
  'main_crunched_leg_drop',
  'main_bridge_walk',
  'main_squat_into_abductors',
  'main_alternating_side_lunges',
  'main_alternating_lunges',
  'main_plank_jacks',
  'main_heel_touches',
  'main_lying_opposite_leg_arm_lifts',
  'sup_dead_bug',
  'main_sit_up_single_leg_knee_in',
  'main_frog_jumps',
  'main_opposite_arm_leg_extensions',
  'main_knee_bend_kicks',
  'main_switch_kicks',
  'main_flutter_clap',
  'main_speed_skater',
  'main_squat_to_knee_up',
};

const _cooldownExerciseIds = <String>{
  'cd_worlds_greatest_left',
  'cd_worlds_greatest_right',
  'cd_supine_spinal_twist_left',
  'cd_supine_spinal_twist_right',
  'cd_overhead_triceps_left',
  'cd_overhead_triceps_right',
  'prone_cobra',
  'cd_figure_four_right',
  'cd_happy_baby',
  'cd_frog_stretch',
  'cd_seated_glute_left',
  'cd_seated_glute_right',
  'cd_back_stretch_standing',
  'cd_anterior_shoulder_stretch',
  'cd_seated_butterfly_stretch',
  'cd_lateral_knee_drops',
  'cd_wide_forward_fold',
  'cd_chest_opener',
  'cd_belly_breathing',
  'cd_knee_rolls',
  'cd_squat_twists',
};

const _warmupIdsByDay = <int, List<String>>{
  1: ['wu_cross_toe_touch', 'wu_high_knees_arm_drive'],
  2: ['wu_leg_swing_front_back_right', 'wu_leg_swing_front_back_left'],
  3: ['wu_arm_swings', 'wu_front_to_side_arm_raises'],
  4: ['wu_overhead_press_wide_steps', 'wu_clapping_steps'],
  5: ['wu_squat_to_stand', 'wu_side_to_side_squat_hold'],
  6: ['wu_standing_scapular_retraction', 'wu_shoulder_circles'],
  7: ['wu_standing_trunk_rotation', 'wu_standing_core_brace_march'],
  8: ['wu_wide_toe_touches', 'wu_big_arm_circles'],
  9: ['wu_walking_side_high_knee', 'wu_toe_touch_side_lunges'],
  10: ['wu_small_arm_circles', 'wu_bent_over_wing_flys'],
  11: ['wu_squat_reach_jacks', 'wu_skaters_double_steps'],
  12: ['stand_hip_circles', 'wu_alternate_leg_reaches'],
  13: ['wu_up_straight_punches', 'wu_chest_claps_calf_raises'],
  14: ['wu_reach_and_twists', 'wu_wide_step_twist'],
  15: ['wu_wide_stance_3_point_reach', 'wu_arm_cross_with_steps'],
  16: ['wu_toe_touch_side_lunges', 'wu_wide_toe_touches'],
  17: ['prone_swimmers', 'wu_side_step_arm_rainbows'],
  18: ['wu_high_knees_arm_drive', 'wu_overhead_press_wide_steps'],
  19: ['wu_leg_swing_front_back_right', 'wu_squat_to_stand'],
  20: ['stand_arm_circles', 'wu_big_arm_circles'],
  21: ['wu_standing_trunk_rotation', 'wu_cross_toe_touch'],
};

const _mainIdsByDay = <int, List<String>>{
  1: [
    'main_standing_arm_punches',
    'main_lateral_lunge_left',
    'main_lateral_lunge_right',
    'knee_bird_dog',
    'prone_pushup',
    'sup_glute_bridge',
    'main_standing_oblique_crunch',
  ],
  2: [
    'squat_bodyweight',
    'main_standing_glute_kickback_left',
    'main_standing_glute_kickback_right',
    'main_fire_hydrant_left',
    'main_fire_hydrant_right',
    'main_standing_calf_raise',
    'main_hip_thrusts',
  ],
  3: [
    'main_standing_triceps_kickback',
    'main_knee_plank_hold',
    'main_prone_cobra',
    'main_scapular_pushup',
    'main_prone_w_activation',
    'main_self_resisted_biceps_curl_left',
    'main_self_resisted_biceps_curl_right',
  ],
  4: [
    'main_mountain_climber',
    'main_squat_heel_tap_jump',
    'main_leg_scissors',
    'main_standing_arm_punches',
    'main_speed_skater',
    'main_bicycle_kicks',
    'main_frog_jumps',
  ],
  5: [
    'main_lateral_lunge_left',
    'main_lateral_lunge_right',
    'main_static_lunge_hold_left',
    'main_static_lunge_hold_right',
    'main_donkey_kick_left',
    'main_donkey_kick_right',
    'sup_glute_bridge',
  ],
  6: [
    'prone_pushup',
    'main_plank_shoulder_tap',
    'main_bent_knee_dead_bug',
    'main_bent_knee_leg_raise',
    'main_seated_knee_tuck',
    'main_knee_pushup',
    'main_pike_pushup',
  ],
  7: [
    'main_plank_hold',
    'main_standing_oblique_crunch',
    'main_seated_twist_arm_opening',
    'sup_russian_twist',
    'main_heel_touches',
    'sup_dead_bug',
    'main_opposite_arm_leg_extensions',
  ],
  8: [
    'main_diamond_pushup',
    'main_side_lunge_and_reach',
    'main_squat_into_abductors',
    'main_crab_reach',
    'main_ab_crunch_leg_extension',
    'main_lying_opposite_leg_arm_lifts',
    'main_standing_arm_punches',
  ],
  9: [
    'squat_bodyweight',
    'main_hip_thrusts',
    'main_bridge_walk',
    'main_alternating_side_lunges',
    'main_alternating_lunges',
    'main_squat_to_knee_up',
    'main_standing_calf_raise',
  ],
  10: [
    'main_knee_pushup',
    'main_diamond_pushup',
    'main_pike_pushup',
    'main_standing_triceps_kickback',
    'main_self_resisted_biceps_curl_left',
    'main_self_resisted_biceps_curl_right',
    'main_plank_hold',
  ],
  11: [
    'main_plank_jacks',
    'main_frog_jumps',
    'main_speed_skater',
    'main_mountain_climber',
    'main_switch_kicks',
    'main_standing_arm_punches',
    'main_bicycle_kicks',
  ],
  12: [
    'main_squat_into_abductors',
    'main_alternating_side_lunges',
    'main_alternating_lunges',
    'main_hip_thrusts',
    'main_crab_reach',
    'main_donkey_kick_left',
    'main_donkey_kick_right',
  ],
  13: [
    'prone_pushup',
    'main_scapular_pushup',
    'main_prone_w_activation',
    'main_prone_cobra',
    'main_plank_shoulder_tap',
    'main_single_leg_v_ups',
    'main_extended_knee_in_outs',
  ],
  14: [
    'main_bent_knee_dead_bug',
    'main_bent_knee_leg_raise',
    'main_bicycle_kicks',
    'main_ab_crunch_leg_extension',
    'main_leg_scissors',
    'main_crunched_leg_drop',
    'main_sit_up_single_leg_knee_in',
  ],
  15: [
    'main_lateral_lunge_left',
    'main_lateral_lunge_right',
    'main_knee_pushup',
    'knee_bird_dog',
    'main_bridge_walk',
    'main_seated_twist_arm_opening',
    'main_pike_pushup',
  ],
  16: [
    'main_static_lunge_hold_left',
    'main_static_lunge_hold_right',
    'main_fire_hydrant_left',
    'main_fire_hydrant_right',
    'main_standing_glute_kickback_left',
    'main_standing_glute_kickback_right',
    'sup_glute_bridge',
  ],
  17: [
    'main_diamond_pushup',
    'main_standing_triceps_kickback',
    'main_self_resisted_biceps_curl_left',
    'main_self_resisted_biceps_curl_right',
    'main_knee_plank_hold',
    'main_flutter_clap',
    'main_lying_opposite_leg_arm_lifts',
  ],
  18: [
    'main_squat_heel_tap_jump',
    'main_frog_jumps',
    'main_speed_skater',
    'main_plank_jacks',
    'main_mountain_climber',
    'main_switch_kicks',
    'main_flutter_clap',
  ],
  19: [
    'squat_bodyweight',
    'main_side_lunge_and_reach',
    'main_hip_thrusts',
    'main_bridge_walk',
    'main_squat_into_abductors',
    'main_alternating_side_lunges',
    'main_alternating_lunges',
  ],
  20: [
    'prone_pushup',
    'main_scapular_pushup',
    'main_prone_w_activation',
    'main_single_leg_v_ups',
    'main_extended_knee_in_outs',
    'main_knee_bend_kicks',
    'main_opposite_arm_leg_extensions',
  ],
  21: [
    'sup_russian_twist',
    'main_heel_touches',
    'sup_dead_bug',
    'main_sit_up_single_leg_knee_in',
    'main_leg_scissors',
    'main_crunched_leg_drop',
    'main_knee_bend_kicks',
  ],
};

const _cooldownIdsByDay = <int, List<String>>{
  1: ['cd_worlds_greatest_left', 'cd_worlds_greatest_right'],
  2: ['cd_seated_glute_left', 'cd_seated_glute_right'],
  3: ['cd_overhead_triceps_left', 'cd_overhead_triceps_right'],
  4: ['cd_happy_baby', 'cd_belly_breathing'],
  5: ['cd_figure_four_right', 'cd_frog_stretch'],
  6: ['prone_cobra', 'cd_back_stretch_standing'],
  7: ['cd_supine_spinal_twist_left', 'cd_supine_spinal_twist_right'],
  8: ['cd_happy_baby', 'cd_chest_opener'],
  9: ['cd_seated_butterfly_stretch', 'cd_wide_forward_fold'],
  10: ['cd_anterior_shoulder_stretch', 'cd_chest_opener'],
  11: ['cd_belly_breathing', 'cd_knee_rolls'],
  12: ['cd_worlds_greatest_left', 'cd_worlds_greatest_right'],
  13: ['cd_back_stretch_standing', 'cd_anterior_shoulder_stretch'],
  14: ['cd_lateral_knee_drops', 'cd_belly_breathing'],
  15: ['cd_squat_twists', 'cd_belly_breathing'],
  16: ['cd_seated_glute_left', 'cd_seated_glute_right'],
  17: ['cd_overhead_triceps_left', 'cd_overhead_triceps_right'],
  18: ['cd_wide_forward_fold', 'cd_back_stretch_standing'],
  19: ['cd_frog_stretch', 'cd_happy_baby'],
  20: ['prone_cobra', 'cd_anterior_shoulder_stretch'],
  21: ['cd_knee_rolls', 'cd_squat_twists'],
};

List<Exercise>? _warmupsForDay({
  required int day,
  required _DayFocus focus,
  required List<Exercise> pool,
  required Random rng,
  required String? avoidFirstId,
}) {
  final ids = _warmupIdsByDay[day];
  if (ids == null) return null;

  final available = {for (final exercise in pool) exercise.id: exercise};
  final picks = <Exercise>[];
  final seen = <String>{};

  for (final id in ids) {
    final exercise = available[id];
    if (exercise == null || seen.contains(exercise.id)) continue;
    picks.add(exercise);
    seen.add(exercise.id);
  }

  if (picks.length < 2) {
    final focusPool = pool
        .where(
          (exercise) =>
              !seen.contains(exercise.id) &&
              _matchesPreparationFocus(exercise, focus),
        )
        .toList(growable: false);
    picks.addAll(
      _pickWarmups(
        pool: focusPool,
        rng: rng,
        avoidFirstId: picks.isEmpty ? avoidFirstId : null,
      ).take(2 - picks.length),
    );
  }

  if (picks.length < 2) {
    seen.addAll(picks.map((exercise) => exercise.id));
    picks.addAll(
      _pickWarmups(
        pool: pool
            .where((exercise) => !seen.contains(exercise.id))
            .toList(growable: false),
        rng: rng,
        avoidFirstId: picks.isEmpty ? avoidFirstId : null,
      ).take(2 - picks.length),
    );
  }

  return picks.length == 2 ? picks : null;
}

List<Exercise>? _cooldownsForDay({
  required int day,
  required _DayFocus focus,
  required List<Exercise> pool,
  required Random rng,
}) {
  final ids = _cooldownIdsByDay[day];
  if (ids == null) return null;

  final available = {for (final exercise in pool) exercise.id: exercise};
  final picks = <Exercise>[];
  final seen = <String>{};

  for (final id in ids) {
    final exercise = available[id];
    if (exercise == null || seen.contains(exercise.id)) continue;
    picks.add(exercise);
    seen.add(exercise.id);
  }

  if (picks.length < 2) {
    final focusPool = pool
        .where(
          (exercise) =>
              !seen.contains(exercise.id) &&
              _matchesPreparationFocus(exercise, focus),
        )
        .toList(growable: false);
    picks.addAll(
      _pickCooldowns(pool: focusPool, rng: rng).take(2 - picks.length),
    );
  }

  if (picks.length < 2) {
    seen.addAll(picks.map((exercise) => exercise.id));
    picks.addAll(
      _pickCooldowns(
        pool: pool
            .where((exercise) => !seen.contains(exercise.id))
            .toList(growable: false),
        rng: rng,
      ).take(2 - picks.length),
    );
  }

  return picks.length == 2 ? picks : null;
}

List<Exercise> _mainExercisesForDay({
  required int day,
  required List<Exercise> pool,
  required _DayFocus focus,
  required FitnessGoal? goal,
  required Random rng,
  required int count,
}) {
  final ids = _mainIdsByDay[day];
  if (ids == null) {
    return _pickMain(
      pool: pool,
      focus: focus,
      goal: goal,
      rng: rng,
      count: count,
    );
  }

  final available = {for (final exercise in pool) exercise.id: exercise};
  final picks = <Exercise>[];
  final seen = <String>{};

  for (final id in ids) {
    final exercise = available[id];
    if (exercise == null || seen.contains(exercise.id)) continue;
    picks.add(exercise);
    seen.add(exercise.id);
  }

  if (picks.length < count) {
    picks.addAll(
      _pickMain(
        pool: pool.where((exercise) => !seen.contains(exercise.id)).toList(),
        focus: focus,
        goal: goal,
        rng: rng,
        count: count - picks.length,
      ),
    );
  }

  return picks.take(count).toList(growable: false);
}

// ---------------------------------------------------------------------------
// Picking — warm-up / main / cool-down
// ---------------------------------------------------------------------------

List<Exercise> _pickWarmups({
  required List<Exercise> pool,
  required Random rng,
  required String? avoidFirstId,
}) {
  final list = pool.toList()..shuffle(rng);
  final picks = <Exercise>[];
  final seen = <String>{};
  for (final ex in list) {
    if (picks.isEmpty && ex.id == avoidFirstId) continue;
    if (seen.contains(ex.id)) continue;
    picks.add(ex);
    seen.add(ex.id);
    if (picks.length == 2) break;
  }
  // Fallback if the pool is very small.
  if (picks.length < 2) {
    for (final ex in pool) {
      if (seen.contains(ex.id)) continue;
      picks.add(ex);
      seen.add(ex.id);
      if (picks.length == 2) break;
    }
  }
  return picks;
}

List<Exercise> _pickCooldowns({
  required List<Exercise> pool,
  required Random rng,
}) {
  final list = pool.toList()..shuffle(rng);
  final seen = <String>{};
  final picks = <Exercise>[];
  for (final ex in list) {
    if (seen.contains(ex.id)) continue;
    picks.add(ex);
    seen.add(ex.id);
    if (picks.length == 2) break;
  }
  return picks;
}

List<Exercise> _pickMain({
  required List<Exercise> pool,
  required _DayFocus focus,
  required FitnessGoal? goal,
  required Random rng,
  required int count,
}) {
  final buckets = _bucketsFor(focus);
  final seen = <String>{};
  final picks = <Exercise>[];

  // Cycle through buckets in priority order — this guarantees the day
  // hits every anatomy category before doubling up on any one.
  for (var i = 0; i < count; i++) {
    final bucket = buckets[i % buckets.length];
    final candidates = pool
        .where((e) => !seen.contains(e.id) && _matchesBucket(e, bucket))
        .toList();
    if (candidates.isEmpty) {
      // Keep the replacement inside the day's overall focus even when one
      // anatomy bucket (for example upper body after "No Prone") runs dry.
      final onFocusLeft = pool
          .where(
            (exercise) =>
                !seen.contains(exercise.id) &&
                buckets.any((candidate) => _matchesBucket(exercise, candidate)),
          )
          .toList(growable: false);
      if (onFocusLeft.isNotEmpty) {
        final chosen = onFocusLeft[rng.nextInt(onFocusLeft.length)];
        picks.add(chosen);
        seen.add(chosen.id);
        continue;
      }

      // Only cross focus when a restrictive preference makes seven relevant
      // unique movements impossible (currently the all-standing upper day).
      final anyLeft = pool.where((e) => !seen.contains(e.id)).toList();
      if (anyLeft.isEmpty) break;
      final chosen = anyLeft[rng.nextInt(anyLeft.length)];
      picks.add(chosen);
      seen.add(chosen.id);
      continue;
    }
    final chosen = candidates[rng.nextInt(candidates.length)];
    picks.add(chosen);
    seen.add(chosen.id);
  }
  return picks;
}

PlanBlock _toBlock(
  Exercise ex,
  PlanPhase phase,
  _SessionShape shape,
  double dayIntensity,
) {
  final sets = switch (phase) {
    PlanPhase.warmup => shape.warmupSets,
    PlanPhase.main => shape.mainSets,
    PlanPhase.cooldown => shape.cooldownSets,
  };
  // Warm-up and cool-down volume shouldn't scale — they're the same drill
  // for a beginner or an advanced trainee. Only the main pool responds to
  // intensity.
  final phaseIntensity = phase == PlanPhase.main
      ? dayIntensity * shape.intensityMultiplier
      : 1.0;
  final scaled = (ex.baseAmount * phaseIntensity).round();
  final floor = ex.unit == ExerciseUnit.seconds ? 15 : 6;
  final amount = max(scaled, floor);
  return PlanBlock(
    exerciseId: ex.id,
    sets: sets,
    amount: amount,
    unit: ex.unit,
    restSeconds: shape.restBetweenSets,
    phase: phase,
  );
}

// ---------------------------------------------------------------------------
// Bucket taxonomy
// ---------------------------------------------------------------------------

enum _Bucket { upper, core, lower, glutes, cardio, mobility, oblique }

bool _matchesPreparationFocus(Exercise exercise, _DayFocus focus) {
  final muscles = {exercise.primary, ...exercise.secondary};

  return switch (focus) {
    _DayFocus.lowerGlute => muscles.any(
      {
        ExerciseMuscle.glutes,
        ExerciseMuscle.quads,
        ExerciseMuscle.hamstrings,
        ExerciseMuscle.innerThighs,
        ExerciseMuscle.calves,
        ExerciseMuscle.hipMobility,
      }.contains,
    ),
    _DayFocus.upperCore => muscles.any(
      {
        ExerciseMuscle.chest,
        ExerciseMuscle.upperBack,
        ExerciseMuscle.shoulders,
        ExerciseMuscle.arms,
        ExerciseMuscle.coreAnterior,
        ExerciseMuscle.obliques,
        ExerciseMuscle.lowerBack,
        ExerciseMuscle.spineMobility,
      }.contains,
    ),
    _DayFocus.coreMobility => muscles.any(
      {
        ExerciseMuscle.coreAnterior,
        ExerciseMuscle.obliques,
        ExerciseMuscle.lowerBack,
        ExerciseMuscle.hipMobility,
        ExerciseMuscle.spineMobility,
      }.contains,
    ),
    _DayFocus.fullBodyCardio || _DayFocus.totalBody => true,
  };
}

List<_Bucket> _bucketsFor(_DayFocus focus) => switch (focus) {
  _DayFocus.upperCore => const [
    _Bucket.upper,
    _Bucket.core,
    _Bucket.oblique,
    _Bucket.upper,
    _Bucket.core,
    _Bucket.oblique,
    _Bucket.upper,
  ],
  _DayFocus.lowerGlute => const [
    _Bucket.glutes,
    _Bucket.lower,
    _Bucket.glutes,
    _Bucket.lower,
    _Bucket.glutes,
    _Bucket.lower,
    _Bucket.glutes,
  ],
  _DayFocus.fullBodyCardio => const [
    _Bucket.cardio,
    _Bucket.cardio,
    _Bucket.cardio,
    _Bucket.cardio,
    _Bucket.cardio,
    _Bucket.cardio,
    _Bucket.cardio,
  ],
  _DayFocus.coreMobility => const [
    _Bucket.core,
    _Bucket.oblique,
    _Bucket.mobility,
    _Bucket.core,
    _Bucket.oblique,
    _Bucket.mobility,
    _Bucket.core,
  ],
  _DayFocus.totalBody => const [
    _Bucket.lower,
    _Bucket.upper,
    _Bucket.glutes,
    _Bucket.core,
    _Bucket.cardio,
    _Bucket.upper,
    _Bucket.oblique,
  ],
};

bool _matchesBucket(Exercise e, _Bucket b) {
  switch (b) {
    case _Bucket.upper:
      return {
        ExerciseMuscle.chest,
        ExerciseMuscle.upperBack,
        ExerciseMuscle.shoulders,
        ExerciseMuscle.arms,
      }.contains(e.primary);
    case _Bucket.core:
      return e.primary == ExerciseMuscle.coreAnterior ||
          e.primary == ExerciseMuscle.lowerBack;
    case _Bucket.oblique:
      return e.primary == ExerciseMuscle.obliques;
    case _Bucket.lower:
      return {
        ExerciseMuscle.quads,
        ExerciseMuscle.hamstrings,
        ExerciseMuscle.innerThighs,
        ExerciseMuscle.calves,
      }.contains(e.primary);
    case _Bucket.glutes:
      return e.primary == ExerciseMuscle.glutes;
    case _Bucket.cardio:
      return e.movements.contains(ExerciseMovement.cardio) ||
          e.primary == ExerciseMuscle.fullBody;
    case _Bucket.mobility:
      return e.movements.contains(ExerciseMovement.mobility) ||
          e.primary == ExerciseMuscle.hipMobility ||
          e.primary == ExerciseMuscle.spineMobility;
  }
}

// ---------------------------------------------------------------------------
// Metadata helpers
// ---------------------------------------------------------------------------

int _seedFor(PlanInputs inputs) {
  final buffer = StringBuffer()
    ..write(inputs.weightKg?.round() ?? 0)
    ..write('|')
    ..write(inputs.heightCm?.round() ?? 0)
    ..write('|')
    ..write(inputs.goal?.index ?? -1)
    ..write('|')
    ..write(inputs.fitnessLevel?.index ?? -1)
    ..write('|')
    ..write(inputs.exerciseFrequency?.index ?? -1)
    ..write('|')
    ..write(inputs.workoutDuration?.index ?? -1)
    ..write('|')
    ..write(inputs.workoutPreference?.index ?? -1)
    ..write('|')
    ..write(inputs.trainer?.index ?? -1);
  return buffer.toString().hashCode;
}

PlanTone _tone(PlanInputs inputs) {
  final trainerTone = switch (inputs.trainer) {
    Trainer.hailey => PlanTone.focusedUplifting,
    Trainer.gemma => PlanTone.steadyEncouraging,
    Trainer.amy => PlanTone.firmSupportive,
    null => PlanTone.steadyEncouraging,
  };
  if (inputs.mainReason == MainReason.postpartum) return PlanTone.gentle;
  return trainerTone;
}

String _focusLabel(FitnessGoal? goal) => switch (goal) {
  FitnessGoal.buildStrength => 'Upper body + core',
  FitnessGoal.loseWeight => 'Full body',
  FitnessGoal.recomp => 'Full body',
  FitnessGoal.maintainAndFit => 'Full body',
  null => 'Full body',
};

String _durationLabel(WorkoutDuration? d) => switch (d) {
  WorkoutDuration.under10 => 'Under 10 mins',
  WorkoutDuration.tenToFifteen => '10-15 mins',
  WorkoutDuration.fifteenToTwenty => '15-20 mins',
  WorkoutDuration.twentyToThirty => '20-30 mins',
  null => '15-20 mins',
};

String _planTitle(FitnessGoal? goal) => switch (goal) {
  FitnessGoal.buildStrength => 'Iron Body Build-Up',
  FitnessGoal.loseWeight => 'Full Body Shred & Burn',
  FitnessGoal.recomp => 'Full Body Shred & Build',
  FitnessGoal.maintainAndFit => 'Total Body Reset',
  null => 'Full Body Shred & Build',
};

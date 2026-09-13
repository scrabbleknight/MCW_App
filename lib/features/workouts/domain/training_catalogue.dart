import 'package:military_calisthenics_women/features/plan/domain/exercise_lookup.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// Builds one of the 25 Training-tab routines exclusively from the finished,
/// media-backed MVP exercise library. Warm-ups and cool-downs are paired to
/// the named routine, while every main block is curated rather than selected
/// from a generic category-wide window.
PlanDay buildTrainingDay({
  required TrainingCategoryKey category,
  required int slot,
  required String name,
  required int minutes,
  required int kcal,
}) {
  final prescription = _prescriptionFor(category, slot);
  final mainSets = switch (minutes) {
    <= 12 => 2,
    <= 18 => 3,
    _ => 4,
  };

  return PlanDay(
    dayIndex: trainingDayKey(category, slot),
    title: name,
    warmup: prescription.warmup
        .map((id) => _block(id, PlanPhase.warmup, sets: 1))
        .toList(growable: false),
    main: prescription.main
        .map((id) => _block(id, PlanPhase.main, sets: mainSets))
        .toList(growable: false),
    cooldown: prescription.cooldown
        .map((id) => _block(id, PlanPhase.cooldown, sets: 1))
        .toList(growable: false),
  );
}

PlanBlock _block(String id, PlanPhase phase, {required int sets}) {
  final exercise = findExercise(id);
  if (exercise == null) {
    throw StateError('Training prescription references unknown exercise: $id');
  }

  return PlanBlock(
    exerciseId: id,
    sets: sets,
    amount: exercise.baseAmount,
    unit: exercise.unit,
    restSeconds: phase == PlanPhase.main ? 20 : 5,
    phase: phase,
  );
}

_TrainingPrescription _prescriptionFor(TrainingCategoryKey category, int slot) {
  final main = _mainRoutines[category]?[slot];
  final warmups = _phasePair(_warmupPools[category], slot);
  final cooldowns = _phasePair(_cooldownPools[category], slot);

  if (main == null || warmups == null || cooldowns == null) {
    throw RangeError(
      'No training prescription for ${category.name} slot $slot',
    );
  }

  return _TrainingPrescription(
    warmup: warmups,
    main: main,
    cooldown: cooldowns,
  );
}

List<String>? _phasePair(List<String>? pool, int slot) {
  if (pool == null || slot < 0 || slot >= 5 || pool.length != 10) return null;
  return pool.sublist(slot * 2, slot * 2 + 2);
}

class _TrainingPrescription {
  const _TrainingPrescription({
    required this.warmup,
    required this.main,
    required this.cooldown,
  });

  final List<String> warmup;
  final List<String> main;
  final List<String> cooldown;
}

/// Stable synthetic day index for a training routine. Kept above the 21-day
/// mission range so Training and mission progress cannot collide.
int trainingDayKey(TrainingCategoryKey category, int slot) =>
    10000 + category.index * 100 + slot;

/// Order matches the Training screen categories.
enum TrainingCategoryKey {
  trending,
  combatConditioning,
  battleReadyStrength,
  reconRecovery,
  lowImpactOps,
}

// Each ten-entry phase pool is ordered as five relevant pairs—one pair for
// each routine card in that category.
const _warmupPools = <TrainingCategoryKey, List<String>>{
  TrainingCategoryKey.trending: [
    'wu_cross_toe_touch',
    'wu_high_knees_arm_drive',
    'wu_arm_cross_with_steps',
    'wu_overhead_press_wide_steps',
    'wu_squat_reach_jacks',
    'wu_skaters_double_steps',
    'wu_wide_step_twist',
    'wu_clapping_steps',
    'wu_wide_toe_touches',
    'wu_big_arm_circles',
  ],
  TrainingCategoryKey.combatConditioning: [
    'wu_high_knees_arm_drive',
    'wu_standing_core_brace_march',
    'wu_squat_reach_jacks',
    'wu_skaters_double_steps',
    'wu_overhead_press_wide_steps',
    'wu_clapping_steps',
    'wu_walking_side_high_knee',
    'wu_wide_step_twist',
    'wu_side_to_side_squat_hold',
    'wu_up_straight_punches',
  ],
  TrainingCategoryKey.battleReadyStrength: [
    'wu_squat_to_stand',
    'wu_leg_swing_front_back_right',
    'wu_leg_swing_front_back_left',
    'wu_toe_touch_side_lunges',
    'wu_arm_swings',
    'wu_front_to_side_arm_raises',
    'wu_standing_scapular_retraction',
    'wu_shoulder_circles',
    'wu_bent_over_wing_flys',
    'wu_chest_claps_calf_raises',
  ],
  TrainingCategoryKey.reconRecovery: [
    'wu_standing_trunk_rotation',
    'wu_reach_and_twists',
    'wu_leg_swing_front_back_right',
    'wu_leg_swing_front_back_left',
    'wu_wide_toe_touches',
    'wu_wide_stance_3_point_reach',
    'wu_alternate_leg_reaches',
    'stand_hip_circles',
    'prone_swimmers',
    'stand_arm_circles',
  ],
  TrainingCategoryKey.lowImpactOps: [
    'wu_standing_core_brace_march',
    'wu_arm_swings',
    'wu_side_step_arm_rainbows',
    'wu_standing_scapular_retraction',
    'stand_arm_circles',
    'wu_shoulder_circles',
    'wu_walking_side_high_knee',
    'wu_reach_and_twists',
    'wu_small_arm_circles',
    'wu_big_arm_circles',
  ],
};

const _cooldownPools = <TrainingCategoryKey, List<String>>{
  TrainingCategoryKey.trending: [
    'cd_worlds_greatest_left',
    'cd_worlds_greatest_right',
    'cd_happy_baby',
    'cd_belly_breathing',
    'cd_wide_forward_fold',
    'cd_chest_opener',
    'cd_knee_rolls',
    'cd_back_stretch_standing',
    'cd_lateral_knee_drops',
    'cd_squat_twists',
  ],
  TrainingCategoryKey.combatConditioning: [
    'cd_figure_four_right',
    'cd_belly_breathing',
    'cd_wide_forward_fold',
    'cd_back_stretch_standing',
    'cd_seated_butterfly_stretch',
    'cd_knee_rolls',
    'cd_worlds_greatest_left',
    'cd_worlds_greatest_right',
    'cd_seated_glute_left',
    'cd_seated_glute_right',
  ],
  TrainingCategoryKey.battleReadyStrength: [
    'cd_worlds_greatest_left',
    'cd_worlds_greatest_right',
    'cd_seated_glute_left',
    'cd_seated_glute_right',
    'cd_overhead_triceps_left',
    'cd_overhead_triceps_right',
    'cd_supine_spinal_twist_left',
    'cd_supine_spinal_twist_right',
    'cd_anterior_shoulder_stretch',
    'cd_chest_opener',
  ],
  TrainingCategoryKey.reconRecovery: [
    'cd_seated_glute_left',
    'cd_seated_glute_right',
    'cd_anterior_shoulder_stretch',
    'cd_chest_opener',
    'cd_worlds_greatest_left',
    'cd_worlds_greatest_right',
    'cd_frog_stretch',
    'cd_happy_baby',
    'cd_knee_rolls',
    'cd_belly_breathing',
  ],
  TrainingCategoryKey.lowImpactOps: [
    'cd_seated_butterfly_stretch',
    'cd_happy_baby',
    'cd_wide_forward_fold',
    'cd_belly_breathing',
    'cd_overhead_triceps_left',
    'cd_overhead_triceps_right',
    'cd_supine_spinal_twist_left',
    'cd_supine_spinal_twist_right',
    'prone_cobra',
    'cd_back_stretch_standing',
  ],
};

// Seven media-backed main movements per routine. Left/right movements remain
// paired, and the recovery/low-impact prescriptions deliberately avoid jumps.
const _mainRoutines = <TrainingCategoryKey, Map<int, List<String>>>{
  TrainingCategoryKey.trending: {
    0: [
      'squat_bodyweight',
      'prone_pushup',
      'main_squat_into_abductors',
      'main_bicycle_kicks',
      'main_hip_thrusts',
      'main_standing_arm_punches',
      'main_speed_skater',
    ],
    1: [
      'main_standing_arm_punches',
      'main_lateral_lunge_left',
      'main_lateral_lunge_right',
      'knee_bird_dog',
      'main_knee_plank_hold',
      'sup_glute_bridge',
      'main_standing_oblique_crunch',
    ],
    2: [
      'main_squat_heel_tap_jump',
      'main_plank_jacks',
      'main_frog_jumps',
      'main_speed_skater',
      'main_mountain_climber',
      'main_switch_kicks',
      'main_flutter_clap',
    ],
    3: [
      'main_diamond_pushup',
      'squat_bodyweight',
      'main_alternating_lunges',
      'main_crunched_leg_drop',
      'main_ab_crunch_leg_extension',
      'main_donkey_kick_left',
      'main_donkey_kick_right',
    ],
    4: [
      'main_standing_arm_punches',
      'main_squat_to_knee_up',
      'main_knee_pushup',
      'main_standing_glute_kickback_left',
      'main_standing_glute_kickback_right',
      'main_bent_knee_dead_bug',
      'main_standing_calf_raise',
    ],
  },
  TrainingCategoryKey.combatConditioning: {
    0: [
      'main_standing_arm_punches',
      'main_lateral_lunge_left',
      'main_lateral_lunge_right',
      'knee_bird_dog',
      'main_knee_pushup',
      'sup_glute_bridge',
      'main_mountain_climber',
    ],
    1: [
      'main_speed_skater',
      'main_squat_heel_tap_jump',
      'main_bicycle_kicks',
      'main_mountain_climber',
      'main_leg_scissors',
      'main_plank_jacks',
      'main_flutter_clap',
    ],
    2: [
      'main_diamond_pushup',
      'main_pike_pushup',
      'main_frog_jumps',
      'main_plank_jacks',
      'main_squat_into_abductors',
      'main_crab_reach',
      'main_lying_opposite_leg_arm_lifts',
    ],
    3: [
      'main_standing_arm_punches',
      'main_squat_to_knee_up',
      'main_switch_kicks',
      'main_mountain_climber',
      'main_alternating_lunges',
      'main_knee_pushup',
      'main_bent_knee_dead_bug',
    ],
    4: [
      'main_speed_skater',
      'main_frog_jumps',
      'prone_pushup',
      'main_plank_shoulder_tap',
      'main_alternating_side_lunges',
      'main_bicycle_kicks',
      'main_hip_thrusts',
    ],
  },
  TrainingCategoryKey.battleReadyStrength: {
    0: [
      'squat_bodyweight',
      'prone_pushup',
      'main_alternating_lunges',
      'main_hip_thrusts',
      'main_plank_shoulder_tap',
      'main_prone_w_activation',
      'sup_russian_twist',
    ],
    1: [
      'main_diamond_pushup',
      'main_pike_pushup',
      'main_static_lunge_hold_left',
      'main_static_lunge_hold_right',
      'main_hip_thrusts',
      'main_bridge_walk',
      'main_single_leg_v_ups',
    ],
    2: [
      'squat_bodyweight',
      'main_lateral_lunge_left',
      'main_lateral_lunge_right',
      'main_standing_triceps_kickback',
      'main_self_resisted_biceps_curl_left',
      'main_self_resisted_biceps_curl_right',
      'sup_glute_bridge',
    ],
    3: [
      'main_mountain_climber',
      'main_plank_hold',
      'main_bent_knee_dead_bug',
      'main_bent_knee_leg_raise',
      'main_extended_knee_in_outs',
      'main_bicycle_kicks',
      'sup_dead_bug',
    ],
    4: [
      'prone_pushup',
      'main_knee_pushup',
      'main_diamond_pushup',
      'main_pike_pushup',
      'main_scapular_pushup',
      'main_plank_shoulder_tap',
      'main_standing_triceps_kickback',
    ],
  },
  TrainingCategoryKey.reconRecovery: {
    0: [
      'sup_glute_bridge',
      'main_standing_glute_kickback_left',
      'main_standing_glute_kickback_right',
      'main_fire_hydrant_left',
      'main_fire_hydrant_right',
      'main_standing_calf_raise',
      'main_knee_bend_kicks',
    ],
    1: [
      'main_prone_cobra',
      'main_scapular_pushup',
      'main_prone_w_activation',
      'main_standing_triceps_kickback',
      'main_self_resisted_biceps_curl_left',
      'main_self_resisted_biceps_curl_right',
      'main_seated_twist_arm_opening',
    ],
    2: [
      'knee_bird_dog',
      'main_bent_knee_dead_bug',
      'main_standing_oblique_crunch',
      'main_seated_knee_tuck',
      'main_side_lunge_and_reach',
      'main_lying_opposite_leg_arm_lifts',
      'sup_dead_bug',
    ],
    3: [
      'main_hip_thrusts',
      'main_crab_reach',
      'main_bridge_walk',
      'main_squat_into_abductors',
      'main_side_lunge_and_reach',
      'main_donkey_kick_left',
      'main_donkey_kick_right',
    ],
    4: [
      'main_knee_plank_hold',
      'main_bent_knee_dead_bug',
      'main_bent_knee_leg_raise',
      'main_heel_touches',
      'main_opposite_arm_leg_extensions',
      'main_sit_up_single_leg_knee_in',
      'sup_glute_bridge',
    ],
  },
  TrainingCategoryKey.lowImpactOps: {
    0: [
      'main_standing_triceps_kickback',
      'knee_bird_dog',
      'main_knee_plank_hold',
      'main_prone_cobra',
      'sup_glute_bridge',
      'main_standing_glute_kickback_left',
      'main_standing_glute_kickback_right',
    ],
    1: [
      'main_standing_arm_punches',
      'main_self_resisted_biceps_curl_left',
      'main_self_resisted_biceps_curl_right',
      'main_standing_oblique_crunch',
      'main_standing_glute_kickback_left',
      'main_standing_glute_kickback_right',
      'main_standing_calf_raise',
    ],
    2: [
      'main_standing_arm_punches',
      'main_standing_triceps_kickback',
      'main_self_resisted_biceps_curl_left',
      'main_self_resisted_biceps_curl_right',
      'main_standing_oblique_crunch',
      'main_standing_glute_kickback_left',
      'main_standing_glute_kickback_right',
    ],
    3: [
      'main_knee_pushup',
      'knee_bird_dog',
      'main_bent_knee_dead_bug',
      'main_seated_knee_tuck',
      'sup_glute_bridge',
      'main_fire_hydrant_left',
      'main_fire_hydrant_right',
    ],
    4: [
      'main_knee_plank_hold',
      'main_plank_shoulder_tap',
      'knee_bird_dog',
      'main_hip_thrusts',
      'main_crab_reach',
      'main_lying_opposite_leg_arm_lifts',
      'sup_dead_bug',
    ],
  },
};

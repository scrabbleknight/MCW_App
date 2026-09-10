import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// Composes a [PlanDay] for a Training-tab routine by drawing from curated
/// per-category pools. Each routine gets 2 warmup + 12 main + 2 cooldown
/// blocks — a rotating window over the pool keeps every routine in a
/// category distinct without hand-authoring 400 rows.
///
/// The `dayIndex` we assign is synthetic (10 000 + hash) so the starred-
/// workouts controller keys these separately from the 21-day mission days.
PlanDay buildTrainingDay({
  required TrainingCategoryKey category,
  required int slot,
  required String name,
  required int minutes,
  required int kcal,
}) {
  final warmup = _pick(_warmupPool, slot * 2, 2)
      .map((id) => PlanBlock(
            exerciseId: id,
            sets: 1,
            amount: 45,
            unit: ExerciseUnit.seconds,
            restSeconds: 10,
            phase: PlanPhase.warmup,
          ))
      .toList(growable: false);

  final mainIds = _pick(_mainPools[category]!, slot * 2, 12);
  final main = <PlanBlock>[
    for (final id in mainIds)
      PlanBlock(
        exerciseId: id,
        sets: 3,
        amount: _defaultAmountForMain(id),
        unit: _unitForMain(id),
        restSeconds: 20,
        phase: PlanPhase.main,
      ),
  ];

  final cooldown = _pick(_cooldownPool, slot * 2, 2)
      .map((id) => PlanBlock(
            exerciseId: id,
            sets: 1,
            amount: 45,
            unit: ExerciseUnit.seconds,
            restSeconds: 5,
            phase: PlanPhase.cooldown,
          ))
      .toList(growable: false);

  final synthIndex = trainingDayKey(category, slot);
  return PlanDay(
    dayIndex: synthIndex,
    title: name,
    warmup: warmup,
    main: main,
    cooldown: cooldown,
  );
}

/// Stable synthetic day index for a training routine. Kept above the 21-day
/// mission range so [TrainingProgressController] and the mission
/// [ProgressController] can't ever collide on a key.
int trainingDayKey(TrainingCategoryKey category, int slot) =>
    10000 + category.index * 100 + slot;

/// Which category this routine belongs to — used to select the right main-
/// exercise pool. Order matches [TrainingScreen._categories].
enum TrainingCategoryKey {
  trending,
  combatConditioning,
  battleReadyStrength,
  reconRecovery,
  lowImpactOps,
}

/// Rotating slice of [pool] starting at [start], wrapping around and never
/// repeating within the returned list. Deterministic per (start, count).
List<String> _pick(List<String> pool, int start, int count) {
  final out = <String>[];
  for (var i = 0; i < count; i++) {
    out.add(pool[(start + i) % pool.length]);
  }
  return out;
}

/// Reps for rep-based main exercises, seconds for hold/cardio-based ones.
int _defaultAmountForMain(String id) => _unitForMain(id) == ExerciseUnit.seconds ? 40 : 12;

/// Seconds for holds/planks/cardio bursts; reps for everything else.
ExerciseUnit _unitForMain(String id) {
  const secondBased = {
    'stand_wall_sit',
    'squat_hold',
    'prone_forearm_plank',
    'prone_plank_shoulder_tap',
    'prone_plank_hip_dip',
    'prone_up_down_plank',
    'main_high_plank',
    'main_dynamic_plank',
    'main_pushup_hold',
    'main_wall_hold_pulses',
    'main_reverse_plank',
    'main_dead_bug_holds',
    'main_low_impact_climber',
    'main_seated_twist_reach',
    'sup_hollow_hold',
    'sup_flutter_kick',
    'sup_scissor',
    'bear_hold',
    'side_plank',
    'side_plank_hip_dip',
    'stand_high_knees',
    'stand_jumping_jacks',
    'stand_skater_hops',
    'stand_shadow_box',
    'stand_cross_punches',
    'full_mountain_climber',
    'full_slow_climber',
    'full_cross_climber',
    'full_butt_kicks',
    'full_star_jump',
    'full_inchworm',
    'main_speed_skater',
    'main_knee_drive',
    'main_squat_thrust',
  };
  return secondBased.contains(id) ? ExerciseUnit.seconds : ExerciseUnit.reps;
}

// ---------------------------------------------------------------------------
// Shared warmup / cooldown pools — every routine draws from these so the
// prep and recovery phases feel consistent across the whole Training tab.
// ---------------------------------------------------------------------------

const List<String> _warmupPool = [
  'wu_neck_rolls',
  'wu_shoulder_rolls',
  'wu_side_bends',
  'wu_leg_swings_front',
  'wu_leg_swings_side',
  'wu_ankle_circles',
  'wu_wrist_circles',
  'wu_hip_openers',
  'wu_world_greatest',
  'wu_downdog_pedals',
  'wu_thoracic_rotation',
  'wu_scap_pushup',
  'wu_glute_activation',
  'wu_toe_touch_reach',
  'wu_cross_toe_touch',
  'wu_arm_swings',
  'wu_knee_hug_walk',
  'wu_shadow_jab',
];

const List<String> _cooldownPool = [
  'cd_child_pose',
  'cd_seated_forward_fold',
  'cd_butterfly',
  'cd_pigeon',
  'cd_supine_twist',
  'cd_hamstring_stretch',
  'cd_quad_stretch',
  'cd_hip_flexor',
  'cd_figure_four',
  'cd_cobra_hold',
  'cd_downdog_hold',
  'cd_thread_needle_hold',
  'cd_cat_cow_slow',
  'cd_box_breath',
  'cd_chest_opener',
  'cd_calf_stretch',
  'cd_neck_stretch',
  'cd_savasana',
];

// ---------------------------------------------------------------------------
// Per-category main pools. Each has at least 20 IDs so five routines can
// each grab a distinct 12-block slice via the rotation window.
// ---------------------------------------------------------------------------

const Map<TrainingCategoryKey, List<String>> _mainPools = {
  TrainingCategoryKey.trending: [
    'stand_high_knees',
    'stand_jumping_jacks',
    'squat_bodyweight',
    'squat_jump',
    'lunge_forward',
    'prone_pushup',
    'sup_crunch',
    'sup_bicycle_crunch',
    'full_burpee',
    'full_mountain_climber',
    'full_star_jump',
    'main_squat_kick',
    'main_speed_skater',
    'main_squat_press',
    'stand_shadow_box',
    'main_knee_drive',
    'sup_russian_twist',
    'main_pushup_reach',
    'lunge_jumping',
    'main_dynamic_plank',
    'full_half_burpee',
    'sup_flutter_kick',
    'sup_v_up',
    'prone_forearm_plank',
  ],
  TrainingCategoryKey.combatConditioning: [
    'full_burpee',
    'full_half_burpee',
    'full_mountain_climber',
    'full_star_jump',
    'full_butt_kicks',
    'full_cross_climber',
    'stand_high_knees',
    'stand_jumping_jacks',
    'stand_skater_hops',
    'squat_jump',
    'lunge_jumping',
    'main_squat_thrust',
    'main_knee_drive',
    'main_speed_skater',
    'stand_cross_punches',
    'stand_front_kick',
    'stand_side_kick',
    'stand_rear_kick',
    'main_squat_kick',
    'main_low_impact_climber',
    'main_squat_pulse_hold',
    'stand_shadow_box',
    'full_inchworm',
    'main_pushup_shoulder_tap',
  ],
  TrainingCategoryKey.battleReadyStrength: [
    'squat_bodyweight',
    'squat_sumo',
    'squat_hold',
    'squat_pulse',
    'lunge_forward',
    'lunge_reverse',
    'lunge_lateral',
    'lunge_curtsy',
    'prone_pushup',
    'prone_wide_pushup',
    'prone_diamond_pushup',
    'prone_knee_pushup',
    'sup_glute_bridge',
    'sup_hip_thrust',
    'sup_single_leg_bridge',
    'prone_superman',
    'prone_forearm_plank',
    'main_pushup_reach',
    'main_negative_pushup',
    'main_deadlift_reach',
    'main_glute_kickback',
    'main_frog_pump',
    'main_reverse_lunge_kick',
    'main_wall_hold_pulses',
  ],
  TrainingCategoryKey.reconRecovery: [
    'wu_world_greatest',
    'wu_hip_openers',
    'wu_thoracic_rotation',
    'wu_downdog_pedals',
    'knee_cat_cow',
    'knee_thread_needle',
    'knee_bird_dog',
    'prone_cobra',
    'prone_ytw',
    'prone_swimmers',
    'cd_pigeon',
    'cd_hamstring_stretch',
    'cd_hip_flexor',
    'cd_figure_four',
    'cd_supine_twist',
    'cd_thread_needle_hold',
    'cd_downdog_hold',
    'cd_seated_forward_fold',
    'cd_butterfly',
    'cd_cobra_hold',
    'cd_chest_opener',
    'cd_cat_cow_slow',
    'wu_glute_activation',
    'sup_dead_bug',
  ],
  TrainingCategoryKey.lowImpactOps: [
    'stand_march',
    'stand_arm_circles',
    'stand_wall_pushup',
    'stand_wall_sit',
    'stand_y_raise',
    'stand_torso_rotation',
    'stand_windmill',
    'stand_toe_touches',
    'stand_hip_circles',
    'stand_halo',
    'stand_bear_hug_stretch',
    'stand_tricep_ext',
    'knee_bird_dog',
    'knee_cat_cow',
    'knee_fire_hydrant',
    'knee_donkey_kick',
    'sup_glute_bridge',
    'sup_dead_bug',
    'sup_leg_raise',
    'sup_flutter_kick',
    'main_wall_hold_pulses',
    'main_dead_bug_holds',
    'main_seated_twist_reach',
    'main_low_impact_climber',
  ],
};

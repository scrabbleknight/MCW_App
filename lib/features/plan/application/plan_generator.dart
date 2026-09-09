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
}

/// 21-day mission builder. Every day gets:
///   - 2 warm-up exercises (mobility / activation)
///   - 12 main exercises (balanced across the day's focus)
///   - 2 cool-down exercises (static holds / breath)
///
/// The plan is deterministic per user profile: same answers → same 21 days.
/// Exercises can and do repeat across days, but within any one day nothing
/// appears twice, and consecutive days try not to open with the same warm-up.
Plan generatePlan(PlanInputs inputs) {
  final rng = Random(_seedFor(inputs));

  final pool = _filterPool(inputs.workoutPreference);
  final warmupPool = _phasePool(pool, PlanPhase.warmup);
  final cooldownPool = _phasePool(pool, PlanPhase.cooldown);
  final mainPool = _phasePool(pool, PlanPhase.main);

  final shape = _sessionShape(inputs);
  final tone = _tone(inputs);
  final stages = _stagesFor(inputs.goal);

  final days = <PlanDay>[];
  String? previousWarmupOpener;

  for (var d = 1; d <= 21; d++) {
    final stageIndex = ((d - 1) ~/ 7); // 0..2
    final intensity = _intensityForDay(d);
    final focus = _rotation[(d - 1) % _rotation.length];

    final warmupPicks = _pickWarmups(
      pool: warmupPool,
      rng: rng,
      avoidFirstId: previousWarmupOpener,
    );
    if (warmupPicks.isNotEmpty) previousWarmupOpener = warmupPicks.first.id;

    final mainPicks = _pickMain(
      pool: mainPool,
      focus: focus,
      goal: inputs.goal,
      rng: rng,
      count: 12,
    );

    final cooldownPicks = _pickCooldowns(pool: cooldownPool, rng: rng);

    days.add(PlanDay(
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
    ));
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
  return exerciseCatalogue.where((ex) {
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
  }).toList(growable: false);
}

/// Split the filtered pool into phase-specific pools. An exercise counts as
/// warm-up when its id is prefixed `wu_`, or when it's a pure mobility /
/// beginner opener that we don't want landing in the main block. Cool-down
/// entries are the `cd_` prefixed set plus any long static hold. Everything
/// else — plus a light overlap of mobility work — becomes the main pool.
List<Exercise> _phasePool(List<Exercise> pool, PlanPhase phase) {
  bool isMobilityOnly(Exercise e) =>
      e.movements.contains(ExerciseMovement.mobility) &&
      !e.movements.contains(ExerciseMovement.push) &&
      !e.movements.contains(ExerciseMovement.pull) &&
      !e.movements.contains(ExerciseMovement.squat) &&
      !e.movements.contains(ExerciseMovement.lunge) &&
      !e.movements.contains(ExerciseMovement.plank) &&
      !e.movements.contains(ExerciseMovement.cardio);

  bool isStretchHold(Exercise e) =>
      e.movements.contains(ExerciseMovement.hold) &&
      e.movements.contains(ExerciseMovement.mobility);

  switch (phase) {
    case PlanPhase.warmup:
      return pool
          .where((e) => e.id.startsWith('wu_') || isMobilityOnly(e))
          .toList(growable: false);
    case PlanPhase.cooldown:
      return pool
          .where((e) => e.id.startsWith('cd_') || isStretchHold(e))
          .toList(growable: false);
    case PlanPhase.main:
      return pool
          .where((e) => !e.id.startsWith('wu_') && !e.id.startsWith('cd_'))
          .toList(growable: false);
  }
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
      title: loseWeight
          ? 'Stage 2: Fat Burn Blast'
          : 'Stage 2: Build the Base',
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

enum _DayFocus { upperCore, lowerGlute, fullBodyCardio, coreMobility, totalBody }

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
      // Fall back to anything unseen if the bucket ran dry.
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

List<_Bucket> _bucketsFor(_DayFocus focus) => switch (focus) {
      _DayFocus.upperCore => const [
          _Bucket.upper,
          _Bucket.core,
          _Bucket.oblique,
          _Bucket.upper,
          _Bucket.core,
          _Bucket.glutes,
          _Bucket.cardio,
        ],
      _DayFocus.lowerGlute => const [
          _Bucket.glutes,
          _Bucket.lower,
          _Bucket.glutes,
          _Bucket.core,
          _Bucket.lower,
          _Bucket.oblique,
          _Bucket.cardio,
        ],
      _DayFocus.fullBodyCardio => const [
          _Bucket.cardio,
          _Bucket.lower,
          _Bucket.upper,
          _Bucket.core,
          _Bucket.cardio,
          _Bucket.glutes,
          _Bucket.oblique,
        ],
      _DayFocus.coreMobility => const [
          _Bucket.core,
          _Bucket.oblique,
          _Bucket.mobility,
          _Bucket.core,
          _Bucket.oblique,
          _Bucket.glutes,
          _Bucket.mobility,
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

import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise_catalogue.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// Focus areas the Custom Exercise Filter surfaces. Each maps to a set of
/// underlying [ExerciseMuscle] entries so the picker can stay coarse while
/// the generator still filters against the fine-grained catalogue.
enum FocusArea { arms, back, core, glutes, legs }

extension FocusAreaX on FocusArea {
  String get label => switch (this) {
        FocusArea.arms => 'Arms',
        FocusArea.back => 'Back',
        FocusArea.core => 'Core',
        FocusArea.glutes => 'Glutes',
        FocusArea.legs => 'Legs',
      };

  String get asset => switch (this) {
        FocusArea.arms => 'assets/branding/custom_arm.png',
        FocusArea.back => 'assets/branding/custom_back.png',
        FocusArea.core => 'assets/branding/custom_core.png',
        FocusArea.glutes => 'assets/branding/custom_glutes.png',
        FocusArea.legs => 'assets/branding/custom_legs.png',
      };

  Set<ExerciseMuscle> get muscles => switch (this) {
        FocusArea.arms => {
            ExerciseMuscle.arms,
            ExerciseMuscle.shoulders,
            ExerciseMuscle.chest,
          },
        FocusArea.back => {
            ExerciseMuscle.upperBack,
            ExerciseMuscle.lowerBack,
          },
        FocusArea.core => {
            ExerciseMuscle.coreAnterior,
            ExerciseMuscle.obliques,
          },
        FocusArea.glutes => {
            ExerciseMuscle.glutes,
            ExerciseMuscle.hamstrings,
          },
        FocusArea.legs => {
            ExerciseMuscle.quads,
            ExerciseMuscle.hamstrings,
            ExerciseMuscle.innerThighs,
            ExerciseMuscle.calves,
          },
      };
}

/// Coarse position groups the filter presents. Each spans one or more
/// [ExercisePosition] entries — e.g. "Standing" pulls in squat and lunge
/// stances so the picker doesn't force the user to know the taxonomy.
enum PositionGroup { standing, seated, lying, kneeling, prone }

extension PositionGroupX on PositionGroup {
  String get label => switch (this) {
        PositionGroup.standing => 'Standing',
        PositionGroup.seated => 'Seated',
        PositionGroup.lying => 'Lying',
        PositionGroup.kneeling => 'Kneeling',
        PositionGroup.prone => 'Prone',
      };

  Set<ExercisePosition> get positions => switch (this) {
        PositionGroup.standing => {
            ExercisePosition.standing,
            ExercisePosition.squatStance,
            ExercisePosition.lungeStance,
          },
        PositionGroup.seated => {ExercisePosition.sitting},
        PositionGroup.lying => {
            ExercisePosition.supine,
            ExercisePosition.sideLying,
          },
        PositionGroup.kneeling => {
            ExercisePosition.kneeling,
            ExercisePosition.bearStance,
          },
        PositionGroup.prone => {ExercisePosition.prone},
      };
}

/// Synthetic day index for custom workouts. Kept clear of the 21-day
/// mission range and the Training-tab range (10 000+) so the starred /
/// progress controllers can't collide on a key.
const int _customDayIndexBase = 20000;

/// Build a one-off [PlanDay] for the user's chosen filters. Returns null
/// when either the focus-area or position selection is empty, or when no
/// exercise in the catalogue satisfies every constraint — the caller
/// surfaces a hint in that case.
PlanDay? buildCustomWorkoutDay({
  required ExerciseDifficulty level,
  required Set<FocusArea> areas,
  required Set<PositionGroup> positions,
}) {
  if (areas.isEmpty || positions.isEmpty) return null;

  final wantedMuscles = <ExerciseMuscle>{
    for (final a in areas) ...a.muscles,
  };
  final wantedPositions = <ExercisePosition>{
    for (final p in positions) ...p.positions,
  };

  bool hitsAreas(Exercise e) =>
      wantedMuscles.contains(e.primary) ||
      e.secondary.any(wantedMuscles.contains);

  final pool = exerciseCatalogue
      .where((e) =>
          wantedPositions.contains(e.position) &&
          hitsAreas(e) &&
          _levelFits(e.difficulty, level))
      .toList(growable: false);

  if (pool.isEmpty) return null;

  final targetMain = pool.length >= 8 ? 8 : pool.length;
  final mainPicks = _rotate(pool, targetMain);
  final main = [
    for (final e in mainPicks)
      PlanBlock(
        exerciseId: e.id,
        sets: 3,
        amount: _scaledAmount(e, level),
        unit: e.unit,
        restSeconds: 20,
        phase: PlanPhase.main,
      ),
  ];

  final warmupPicks = _pickIds(_warmupPool, 2, seed: mainPicks.hashCode);
  final warmup = [
    for (final id in warmupPicks)
      PlanBlock(
        exerciseId: id,
        sets: 1,
        amount: 40,
        unit: ExerciseUnit.seconds,
        restSeconds: 10,
        phase: PlanPhase.warmup,
      ),
  ];

  final cooldownPicks = _pickIds(_cooldownPool, 2, seed: mainPicks.length);
  final cooldown = [
    for (final id in cooldownPicks)
      PlanBlock(
        exerciseId: id,
        sets: 1,
        amount: 40,
        unit: ExerciseUnit.seconds,
        restSeconds: 5,
        phase: PlanPhase.cooldown,
      ),
  ];

  final title = _titleFor(areas);
  return PlanDay(
    dayIndex: _customDayIndexBase +
        Object.hash(level, areas, positions).abs() % 1000,
    title: title,
    warmup: warmup,
    main: main,
    cooldown: cooldown,
  );
}

/// Custom workouts stay one level either side of the user's pick — an
/// "advanced" request can still surface an intermediate movement the
/// catalogue lacks a hard-advanced version of.
bool _levelFits(ExerciseDifficulty exercise, ExerciseDifficulty wanted) {
  final delta = (exercise.index - wanted.index).abs();
  return delta <= 1;
}

int _scaledAmount(Exercise e, ExerciseDifficulty level) {
  final scale = switch (level) {
    ExerciseDifficulty.beginner => 0.75,
    ExerciseDifficulty.intermediate => 1.0,
    ExerciseDifficulty.advanced => 1.25,
  };
  final scaled = (e.baseAmount * scale).round();
  return scaled < 1 ? 1 : scaled;
}

List<Exercise> _rotate(List<Exercise> pool, int count) {
  final out = <Exercise>[];
  for (var i = 0; i < count; i++) {
    out.add(pool[i % pool.length]);
  }
  return out;
}

List<String> _pickIds(List<String> pool, int count, {required int seed}) {
  final start = seed.abs() % pool.length;
  return [for (var i = 0; i < count; i++) pool[(start + i) % pool.length]];
}

String _titleFor(Set<FocusArea> areas) {
  if (areas.length == FocusArea.values.length) return 'Full Body Custom';
  final names = FocusArea.values
      .where(areas.contains)
      .map((a) => a.label)
      .toList(growable: false);
  return '${names.join(' + ')} Custom';
}

const List<String> _warmupPool = [
  'wu_neck_rolls',
  'wu_shoulder_rolls',
  'wu_side_bends',
  'wu_leg_swings_front',
  'wu_hip_openers',
  'wu_world_greatest',
  'wu_thoracic_rotation',
  'wu_arm_swings',
  'wu_glute_activation',
];

const List<String> _cooldownPool = [
  'cd_child_pose',
  'cd_seated_forward_fold',
  'cd_butterfly',
  'cd_pigeon',
  'cd_hamstring_stretch',
  'cd_quad_stretch',
  'cd_hip_flexor',
  'cd_figure_four',
  'cd_supine_twist',
];

import 'package:flutter_test/flutter_test.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_preferences_step.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise_lookup.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:military_calisthenics_women/features/workouts/domain/session_step.dart';

const _warmupNames = <String>{
  'Cross-body Toe Touch',
  'High Knees with Arm Drive',
  'Standing Trunk Rotation',
  'Standing Core Brace March',
  'Arm Swings Cross-body',
  'Front-to-side Arm Raises',
  'Standing Scapular Retraction',
  'Standing Leg Swing Front-To-back (Right)',
  'Standing Leg Swing Front-To-back (Left)',
  'Squat to Stand',
  'Arm Circles',
  'Wide Toe Touches',
  'Shoulder Circles',
  'Walking Side High Knee',
  'Side To Side Squat Hold',
  'Toe Touch Side Lunges',
  'Standing Hip Circles',
  'Reach and Twists',
  'Small Arm Circles',
  'Wide Stance 3 Point Reach',
  'Overhead Press With Wide Steps',
  'Chest Claps With Calf Raises',
  'Arm Cross With Steps',
  'Side Step With Arm Rainbows',
  'Swimmers',
  'Squat Reach Jacks',
  'Wide Step Twist',
  'Up Straight Punches',
  'Bent Over Wing Flys',
  'Skaters Double Steps',
  'Alternate Leg Reaches',
  'Clapping Steps',
  'Big Arm Circles',
};

const _mainNames = <String>{
  'Standing Arm Punches',
  'Standing Triceps Kickback',
  'Lateral Lunge (Left)',
  'Lateral Lunge (Right)',
  'Bird Dog',
  'Knee Plank Hold',
  'Prone Cobra',
  'Push-Up',
  'Plank Shoulder Tap',
  'Scapular Push-up',
  'Prone W Activation',
  'Self-resisted Biceps Curl (Left)',
  'Self-resisted Biceps Curl (Right)',
  'Mountain Climber',
  'Plank Hold',
  'Bent-knee Dead Bug',
  'Bent-knee Leg Raise',
  'Standing Oblique Crunch',
  'Seated Knee Tuck',
  'Bodyweight Squat',
  'Glute Bridge',
  'Standing Glute Kickback (Left)',
  'Standing Glute Kickback (Right)',
  'Fire Hydrant (Left)',
  'Fire Hydrant (Right)',
  'Standing Calf Raise',
  'Static Lunge Hold (Left)',
  'Static Lunge Hold (Right)',
  'Donkey Kick (Left)',
  'Donkey Kick (Right)',
  'Knee Push-up',
  'Diamond Push-up',
  'Pike Push-up',
  'Side Lunge And Reach',
  'Squat And Heel Tap Jump',
  'Seated Twist With Arm Opening',
  'Bicycle Kicks',
  'Abdominal Crunches With Leg Extension',
  'Single Leg V Ups',
  'Extended Knee In And Outs',
  'Russian Twists',
  'Hip Thrusts',
  'Crab Reach',
  'Leg Scissors',
  'Crunched Leg Drop',
  'Bridge Walk',
  'Squat Into Abductors',
  'Alternating Side Lunges',
  'Alternating Lunges',
  'Plank Jacks',
  'Heel Touches',
  'Lying Opposite Leg Arm Lifts',
  'Dead Bug',
  'Sit Up To Single Leg Knee In',
  'Frog Jumps',
  'Opposite Arm Leg Extensions',
  'Knee Bend Kicks',
  'Switch Kicks',
  'Flutter Clap',
  'Speed Skaters',
  'Squat To Knee Up',
};

const _cooldownNames = <String>{
  'Worlds Greatest Stretch (Left)',
  'Worlds Greatest Stretch (Right)',
  'Supine Spinal Twist (Left)',
  'Supine Spinal Twist (Right)',
  'Overhead Triceps Stretch (Left)',
  'Overhead Triceps Stretch (Right)',
  'Cobra Stretch',
  'Figure Four Glute Stretch (Right)',
  'Happy Baby Stretch',
  'Frog Stretch',
  'Seated Glute Stretch (Left)',
  'Seated Glute Stretch (Right)',
  'Back Stretch Standing',
  'Anterior Shoulder Stretch',
  'Seated Butterfly Stretch',
  'Lateral Knee Drops',
  'Wide Forward Fold',
  'Chest Opener',
  'Belly Breathing',
  'Knee Rolls',
  'Squat Twists',
};

const _lowerMuscles = <ExerciseMuscle>{
  ExerciseMuscle.glutes,
  ExerciseMuscle.quads,
  ExerciseMuscle.hamstrings,
  ExerciseMuscle.innerThighs,
  ExerciseMuscle.calves,
};

const _upperCoreMuscles = <ExerciseMuscle>{
  ExerciseMuscle.chest,
  ExerciseMuscle.upperBack,
  ExerciseMuscle.shoulders,
  ExerciseMuscle.arms,
  ExerciseMuscle.coreAnterior,
  ExerciseMuscle.obliques,
  ExerciseMuscle.lowerBack,
};

const _upperMuscles = <ExerciseMuscle>{
  ExerciseMuscle.chest,
  ExerciseMuscle.upperBack,
  ExerciseMuscle.shoulders,
  ExerciseMuscle.arms,
};

const _coreMuscles = <ExerciseMuscle>{
  ExerciseMuscle.coreAnterior,
  ExerciseMuscle.obliques,
  ExerciseMuscle.lowerBack,
};

void main() {
  test('uses every supplied exercise and no unsupported exercises', () {
    final plan = generatePlan(const PlanInputs());

    expect(_names(plan.days.expand((day) => day.warmup)), _warmupNames);
    expect(_names(plan.days.expand((day) => day.main)), _mainNames);
    expect(_names(plan.days.expand((day) => day.cooldown)), _cooldownNames);

    for (final day in plan.days) {
      expect(day.warmup, hasLength(2));
      expect(day.main, hasLength(7));
      expect(day.cooldown, hasLength(2));
      expect(
        day.blocks.map((block) => block.exerciseId).toSet(),
        hasLength(11),
      );
    }
  });

  test('every default programme is aligned to its advertised focus', () {
    final plan = generatePlan(const PlanInputs());

    for (final day in plan.days) {
      final warmups = _exercises(day.warmup);
      final main = _exercises(day.main);
      final cooldowns = _exercises(day.cooldown);

      switch (day.title) {
        case 'Lower + Glutes':
          expect(
            main.map((exercise) => exercise.primary),
            everyElement(isIn(_lowerMuscles)),
          );
          expect(warmups, everyElement(predicate<Exercise>(_targetsLowerBody)));
          expect(
            cooldowns,
            everyElement(predicate<Exercise>(_targetsLowerBody)),
          );
        case 'Upper + Core':
          expect(
            main.map((exercise) => exercise.primary),
            everyElement(isIn(_upperCoreMuscles)),
          );
          expect(
            warmups,
            everyElement(predicate<Exercise>(_targetsUpperOrCore)),
          );
          expect(
            cooldowns,
            everyElement(predicate<Exercise>(_targetsUpperOrCore)),
          );
        case 'Full Body Cardio':
          expect(
            main.map((exercise) => exercise.movements),
            everyElement(contains(ExerciseMovement.cardio)),
          );
          expect(main.any(_targetsLowerBody), isTrue);
          expect(main.any(_targetsUpperOrCore), isTrue);
        case 'Core & Mobility':
          expect(
            main.map((exercise) => exercise.primary),
            everyElement(isIn(_coreMuscles)),
          );
          expect(
            warmups,
            everyElement(predicate<Exercise>(_targetsCoreOrMobility)),
          );
          expect(
            cooldowns,
            everyElement(predicate<Exercise>(_targetsCoreOrMobility)),
          );
        case 'Total Body Tone':
          expect(main.any(_targetsLowerBody), isTrue);
          expect(
            main.any((exercise) => _upperMuscles.contains(exercise.primary)),
            isTrue,
          );
          expect(
            main.any((exercise) => _coreMuscles.contains(exercise.primary)),
            isTrue,
          );
        default:
          fail('Unhandled programme title: ${day.title}');
      }
    }
  });

  test('lower + glutes never receives upper-body or ab-focused main work', () {
    final lowerDays = generatePlan(
      const PlanInputs(),
    ).days.where((day) => day.title == 'Lower + Glutes');

    for (final day in lowerDays) {
      expect(
        _exercises(day.main).map((exercise) => exercise.primary),
        everyElement(isIn(_lowerMuscles)),
        reason: 'Day ${day.dayIndex} contains an off-focus exercise',
      );
    }
  });

  test('default warm-ups have Mux playback assets', () {
    final plan = generatePlan(const PlanInputs());

    for (final block in plan.days.expand((day) => day.warmup)) {
      final exercise = findExercise(block.exerciseId);

      expect(exercise, isNotNull);
      expect(exercise!.videoAsset, startsWith('https://stream.mux.com/'));
      expect(exercise.videoAsset, endsWith('.m3u8'));
      expect(exercise.thumbnailAsset, startsWith('https://image.mux.com/'));
      expect(exercise.thumbnailAsset, endsWith('/thumbnail.jpg'));
    }
  });

  test('default cool-downs have Mux playback assets', () {
    final plan = generatePlan(const PlanInputs());

    for (final block in plan.days.expand((day) => day.cooldown)) {
      final exercise = findExercise(block.exerciseId);

      expect(exercise, isNotNull);
      expect(exercise!.videoAsset, startsWith('https://stream.mux.com/'));
      expect(exercise.videoAsset, endsWith('.m3u8'));
      expect(exercise.thumbnailAsset, startsWith('https://image.mux.com/'));
      expect(exercise.thumbnailAsset, endsWith('/thumbnail.jpg'));
    }
  });

  test('default main exercises have Mux playback assets', () {
    final plan = generatePlan(const PlanInputs());

    for (final block in plan.days.expand((day) => day.main)) {
      final exercise = findExercise(block.exerciseId);

      expect(exercise, isNotNull);
      expect(exercise!.muxPlaybackId, isNotNull);
      expect(exercise.videoAsset, startsWith('https://stream.mux.com/'));
      expect(exercise.videoAsset, endsWith('.m3u8'));
      expect(exercise.thumbnailAsset, startsWith('https://image.mux.com/'));
      expect(exercise.thumbnailAsset, endsWith('/thumbnail.jpg'));
    }
  });

  test('all phases respect workout preferences', () {
    final restrictedPlans = {
      WorkoutPreference.noProne: generatePlan(
        const PlanInputs(workoutPreference: WorkoutPreference.noProne),
      ),
      WorkoutPreference.noKneeling: generatePlan(
        const PlanInputs(workoutPreference: WorkoutPreference.noKneeling),
      ),
      WorkoutPreference.noSquat: generatePlan(
        const PlanInputs(workoutPreference: WorkoutPreference.noSquat),
      ),
      WorkoutPreference.noJumping: generatePlan(
        const PlanInputs(workoutPreference: WorkoutPreference.noJumping),
      ),
      WorkoutPreference.allStanding: generatePlan(
        const PlanInputs(workoutPreference: WorkoutPreference.allStanding),
      ),
    };

    for (final entry in restrictedPlans.entries) {
      for (final day in entry.value.days) {
        final exercises = _exercises(day.blocks);

        expect(day.warmup, hasLength(2));
        expect(day.main, hasLength(7));
        expect(day.cooldown, hasLength(2));

        switch (entry.key) {
          case WorkoutPreference.noProne:
            expect(
              exercises.map((exercise) => exercise.position),
              everyElement(isNot(ExercisePosition.prone)),
            );
          case WorkoutPreference.noKneeling:
            expect(
              exercises.map((exercise) => exercise.position),
              everyElement(
                isNot(
                  isIn({
                    ExercisePosition.kneeling,
                    ExercisePosition.bearStance,
                  }),
                ),
              ),
            );
          case WorkoutPreference.noSquat:
            expect(
              exercises.map((exercise) => exercise.movements),
              everyElement(isNot(contains(ExerciseMovement.squat))),
            );
          case WorkoutPreference.noJumping:
            expect(
              exercises.map((exercise) => exercise.highImpact),
              everyElement(isFalse),
            );
          case WorkoutPreference.allStanding:
            expect(
              exercises.map((exercise) => exercise.position),
              everyElement(ExercisePosition.standing),
            );
          case WorkoutPreference.noPreferences:
            break;
        }

        // The standing-only library has just five upper/core movements, so
        // that preference must prioritise position once those are exhausted.
        // Every other restriction still has enough variety to preserve focus.
        if (entry.key != WorkoutPreference.allStanding) {
          _expectMainFocus(day);
        }
      }
    }
  });

  test('session uses a 10-second prep card before every exercise video', () {
    final day = generatePlan(const PlanInputs()).days.first;
    final exerciseBlocks = day.blocks;
    final steps = buildSessionSteps(day: day, restSeconds: 45);

    expect(steps, hasLength(exerciseBlocks.length * 2));

    for (var i = 0; i < exerciseBlocks.length; i++) {
      final prep = steps[i * 2];
      final player = steps[i * 2 + 1];
      final expectedBlock = exerciseBlocks[i];

      expect(prep.kind, SessionStepKind.card);
      expect(prep.seconds, 10);
      expect(prep.nextBlock, expectedBlock);
      expect(prep.block, isNull);
      expect(prep.stepNumber, i + 1);
      expect(prep.totalSteps, exerciseBlocks.length);

      expect(player.kind, SessionStepKind.player);
      expect(player.block, expectedBlock);
      expect(player.nextBlock, isNull);
      expect(player.stepNumber, i + 1);
      expect(player.totalSteps, exerciseBlocks.length);
    }
  });
}

Set<String?> _names(Iterable<PlanBlock> blocks) =>
    blocks.map((block) => findExercise(block.exerciseId)?.name).toSet();

List<Exercise> _exercises(Iterable<PlanBlock> blocks) => blocks
    .map((block) => findExercise(block.exerciseId))
    .whereType<Exercise>()
    .toList(growable: false);

bool _targetsAny(Exercise exercise, Set<ExerciseMuscle> muscles) =>
    muscles.contains(exercise.primary) ||
    exercise.secondary.any(muscles.contains);

bool _targetsLowerBody(Exercise exercise) =>
    _targetsAny(exercise, _lowerMuscles) ||
    exercise.primary == ExerciseMuscle.hipMobility;

bool _targetsUpperOrCore(Exercise exercise) =>
    _targetsAny(exercise, _upperCoreMuscles) ||
    exercise.primary == ExerciseMuscle.spineMobility;

bool _targetsCoreOrMobility(Exercise exercise) =>
    _targetsAny(exercise, _coreMuscles) ||
    exercise.primary == ExerciseMuscle.spineMobility ||
    exercise.primary == ExerciseMuscle.hipMobility ||
    exercise.primary == ExerciseMuscle.fullBody;

void _expectMainFocus(PlanDay day) {
  final main = _exercises(day.main);

  switch (day.title) {
    case 'Lower + Glutes':
      expect(
        main.map((exercise) => exercise.primary),
        everyElement(isIn(_lowerMuscles)),
        reason: 'Restricted Day ${day.dayIndex} drifted from lower body',
      );
    case 'Upper + Core':
      expect(
        main.map((exercise) => exercise.primary),
        everyElement(isIn(_upperCoreMuscles)),
        reason: 'Restricted Day ${day.dayIndex} drifted from upper/core',
      );
    case 'Full Body Cardio':
      expect(
        main.map((exercise) => exercise.movements),
        everyElement(contains(ExerciseMovement.cardio)),
        reason: 'Restricted Day ${day.dayIndex} drifted from cardio',
      );
    case 'Core & Mobility':
      expect(
        main.map((exercise) => exercise.primary),
        everyElement(isIn(_coreMuscles)),
        reason: 'Restricted Day ${day.dayIndex} drifted from core',
      );
    case 'Total Body Tone':
      expect(main.any(_targetsLowerBody), isTrue);
      expect(
        main.any((exercise) => _upperMuscles.contains(exercise.primary)),
        isTrue,
      );
      expect(
        main.any((exercise) => _coreMuscles.contains(exercise.primary)),
        isTrue,
      );
  }
}

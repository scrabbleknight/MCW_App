import 'package:flutter_test/flutter_test.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise_lookup.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:military_calisthenics_women/features/workouts/domain/training_catalogue.dart';

void main() {
  test('all 25 training routines are complete and media-backed', () {
    final days = _allTrainingDays();

    expect(days, hasLength(25));
    for (final day in days) {
      expect(day.warmup, hasLength(2));
      expect(day.main, hasLength(7));
      expect(day.cooldown, hasLength(2));
      expect(
        day.blocks.map((block) => block.exerciseId).toSet(),
        hasLength(11),
      );

      for (final block in day.blocks) {
        final exercise = findExercise(block.exerciseId);
        expect(exercise, isNotNull, reason: block.exerciseId);
        expect(exercise!.videoAsset, startsWith('https://stream.mux.com/'));
        expect(exercise.thumbnailAsset, startsWith('https://image.mux.com/'));
        expect(block.amount, exercise.baseAmount);
        expect(block.unit, exercise.unit);
      }
    }
  });

  test('Training tab reuses the complete MVP exercise library', () {
    final trainingDays = _allTrainingDays();
    final missionDays = generatePlan(const PlanInputs()).days;

    expect(
      _ids(trainingDays.expand((day) => day.warmup)),
      _ids(missionDays.expand((day) => day.warmup)),
    );
    expect(
      _ids(trainingDays.expand((day) => day.main)),
      _ids(missionDays.expand((day) => day.main)),
    );
    expect(
      _ids(trainingDays.expand((day) => day.cooldown)),
      _ids(missionDays.expand((day) => day.cooldown)),
    );
  });

  test('specialist routines honour their advertised format', () {
    final hiit = _day(TrainingCategoryKey.trending, 2);
    expect(
      _exercises(hiit.main).map((exercise) => exercise.movements),
      everyElement(contains(ExerciseMovement.cardio)),
    );

    final kneeSafe = _day(TrainingCategoryKey.lowImpactOps, 0);
    expect(
      _exercises(kneeSafe.main).map((exercise) => exercise.highImpact),
      everyElement(isFalse),
    );
    expect(
      _exercises(kneeSafe.main).map((exercise) => exercise.movements),
      everyElement(
        allOf(
          isNot(contains(ExerciseMovement.squat)),
          isNot(contains(ExerciseMovement.lunge)),
        ),
      ),
    );

    final standing = _day(TrainingCategoryKey.lowImpactOps, 2);
    expect(
      _exercises(standing.main).map((exercise) => exercise.position),
      everyElement(ExercisePosition.standing),
    );

    final lowImpactDays = List.generate(
      5,
      (slot) => _day(TrainingCategoryKey.lowImpactOps, slot),
    );
    expect(
      lowImpactDays
          .expand((day) => _exercises(day.main))
          .map((exercise) => exercise.highImpact),
      everyElement(isFalse),
    );
  });

  test('shorter and longer routines receive appropriate set counts', () {
    final short = buildTrainingDay(
      category: TrainingCategoryKey.trending,
      slot: 0,
      name: 'Short',
      minutes: 10,
      kcal: 80,
    );
    final medium = buildTrainingDay(
      category: TrainingCategoryKey.trending,
      slot: 0,
      name: 'Medium',
      minutes: 16,
      kcal: 130,
    );
    final long = buildTrainingDay(
      category: TrainingCategoryKey.trending,
      slot: 0,
      name: 'Long',
      minutes: 22,
      kcal: 200,
    );

    expect(short.main.map((block) => block.sets), everyElement(2));
    expect(medium.main.map((block) => block.sets), everyElement(3));
    expect(long.main.map((block) => block.sets), everyElement(4));
  });
}

List<PlanDay> _allTrainingDays() => [
  for (final category in TrainingCategoryKey.values)
    for (var slot = 0; slot < 5; slot++) _day(category, slot),
];

PlanDay _day(TrainingCategoryKey category, int slot) => buildTrainingDay(
  category: category,
  slot: slot,
  name: '${category.name} $slot',
  minutes: 14,
  kcal: 100,
);

Set<String> _ids(Iterable<PlanBlock> blocks) =>
    blocks.map((block) => block.exerciseId).toSet();

List<Exercise> _exercises(Iterable<PlanBlock> blocks) => blocks
    .map((block) => findExercise(block.exerciseId))
    .whereType<Exercise>()
    .toList(growable: false);

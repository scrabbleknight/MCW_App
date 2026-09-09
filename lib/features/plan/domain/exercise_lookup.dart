import 'exercise.dart';
import 'exercise_catalogue.dart';

/// One-shot index of the exercise catalogue. Built once on first access so
/// UI code can go from a [PlanBlock.exerciseId] to the [Exercise] entry
/// without walking the whole list on every card render.
final Map<String, Exercise> exerciseById = {
  for (final ex in exerciseCatalogue) ex.id: ex,
};

Exercise? findExercise(String id) => exerciseById[id];

import 'exercise.dart';

/// A finished plan for a single user. Immutable — regenerate through the
/// plan_generator when their answers change.
class Plan {
  const Plan({
    required this.durationDays,
    required this.dailyCalorieTarget,
    required this.focusAreaLabel,
    required this.sessionDurationLabel,
    required this.title,
    required this.stages,
    required this.days,
    required this.tone,
  });

  final int durationDays;
  final int dailyCalorieTarget;
  final String focusAreaLabel;
  final String sessionDurationLabel;

  /// Marketing-facing name for the whole 21-day mission — e.g.
  /// "Full Body Shred & Build". Derived from the user's goal / focus.
  final String title;

  /// Three stages the 21 days are grouped into (7 days each). The home
  /// screen surfaces the currently-active one as a progress rail.
  final List<PlanStage> stages;

  /// One entry per calendar day of the mission (21 for the standard plan).
  /// Flattened so the home screen can render a simple vertical timeline.
  final List<PlanDay> days;

  /// Coaching-copy tone derived from trainer + main-reason. Consumers pick
  /// message templates based on this, so we don't hard-wire phrasing here.
  final PlanTone tone;
}

/// One 7-day stage inside the 21-day mission. Used only for the home
/// screen's stage rail — the plan generator writes it once and never
/// mutates it.
class PlanStage {
  const PlanStage({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.dayIndices,
  });

  /// 1-based (Stage 1 / 3).
  final int index;
  final String title;
  final String subtitle;

  /// 1-based day numbers this stage covers, e.g. {1,2,3,4,5,6,7}.
  final List<int> dayIndices;
}

class PlanDay {
  const PlanDay({
    required this.dayIndex,
    required this.title,
    required this.warmup,
    required this.main,
    required this.cooldown,
    this.isRest = false,
  });

  /// 1-based day-of-mission (1 … 21), not day-of-week.
  final int dayIndex;
  final String title;
  final bool isRest;

  /// The three phases of the session. Skeleton keeps them separate so the
  /// workout-detail screen can render "Warm up · 2 Exercises", "Main · 7
  /// Exercises", "Cool down · 2 Exercises" straight off the model.
  final List<PlanBlock> warmup;
  final List<PlanBlock> main;
  final List<PlanBlock> cooldown;

  /// Flat view — kept so any consumer that just wants "every block for the
  /// day" (e.g. legacy code, session-timer plumbing) doesn't have to
  /// concatenate manually.
  List<PlanBlock> get blocks => [...warmup, ...main, ...cooldown];

  int get estimatedMinutes {
    if (isRest) return 0;
    var s = 0;
    for (final b in blocks) {
      s += b.estimatedSeconds;
    }
    return (s / 60).round();
  }

  /// Estimated calorie burn — used on the day card. Rough MET-based figure
  /// (~7.5 kcal/min for bodyweight circuits at moderate intensity) so we
  /// don't need per-user weights to render a card at skeleton stage.
  int get estimatedCalories => (estimatedMinutes * 7.5).round();
}

/// One prescribed exercise slot inside a day.
class PlanBlock {
  const PlanBlock({
    required this.exerciseId,
    required this.sets,
    required this.amount,
    required this.unit,
    required this.restSeconds,
    this.phase = PlanPhase.main,
  });

  final String exerciseId;
  final int sets;
  final int amount;
  final ExerciseUnit unit;
  final int restSeconds;
  final PlanPhase phase;

  /// Time cost of one block in the actual session flow: a 10s prep card,
  /// then either the timed hold (seconds unit) or a fixed 45s player for
  /// reps. Mirrors `buildSessionSteps` — sets and per-set rest don't apply
  /// because each block runs once in-session, so folding them in would
  /// inflate the day's preview time above what the user actually spends.
  int get estimatedSeconds {
    const prepSeconds = 10;
    const repsPlayerSeconds = 45;
    final work = unit == ExerciseUnit.seconds ? amount : repsPlayerSeconds;
    return prepSeconds + work;
  }
}

enum PlanPhase { warmup, main, cooldown }

enum PlanTone { firmSupportive, focusedUplifting, steadyEncouraging, gentle }

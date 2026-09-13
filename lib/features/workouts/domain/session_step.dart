import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// What kind of screen [SessionStep] renders as. Prep cards are short
/// countdowns before each exercise; player steps are the actual workout videos.
enum SessionStepKind { card, player }

/// One atomic step in a workout day's session. The session controller walks
/// a flat list of these — each one owns its own countdown, label, and an
/// optional exercise reference.
class SessionStep {
  const SessionStep({
    required this.kind,
    required this.label,
    required this.seconds,
    required this.stepNumber,
    required this.totalSteps,
    this.block,
    this.nextBlock,
  });

  final SessionStepKind kind;

  /// Header shown above the countdown — "FIRST UP", "NEXT UP", …
  final String label;

  final int seconds;

  /// 1-based position within the day (used for the "Step 3/30" caption).
  final int stepNumber;
  final int totalSteps;

  /// The exercise this step centres on. Prep cards use [nextBlock] for the
  /// upcoming exercise; player steps use [block] for the active exercise.
  final PlanBlock? block;
  final PlanBlock? nextBlock;
}

/// Expands a [PlanDay] into the ordered list of steps that make up its
/// session. Every exercise gets a 10-second prep card, then an immersive
/// video player step. This applies to warmups, main exercises, and cooldowns.
List<SessionStep> buildSessionSteps({
  required PlanDay day,
  required int restSeconds,
}) {
  final steps = <SessionStep>[];
  final exerciseSteps =
      day.warmup.length + day.main.length + day.cooldown.length;
  var stepNo = 0;
  const prepSeconds = 10;

  int secondsFor(PlanBlock b) {
    return b.unit == ExerciseUnit.seconds ? b.amount : 45;
  }

  void addExercise(PlanBlock b) {
    stepNo += 1;
    steps
      ..add(
        SessionStep(
          kind: SessionStepKind.card,
          label: stepNo == 1 ? 'FIRST UP' : 'NEXT UP',
          seconds: prepSeconds,
          stepNumber: stepNo,
          totalSteps: exerciseSteps,
          nextBlock: b,
        ),
      )
      ..add(
        SessionStep(
          kind: SessionStepKind.player,
          label: b.unit == ExerciseUnit.seconds ? 'HOLD' : 'GO',
          seconds: secondsFor(b),
          stepNumber: stepNo,
          totalSteps: exerciseSteps,
          block: b,
        ),
      );
  }

  for (final b in day.warmup) {
    addExercise(b);
  }
  for (final b in day.main) {
    addExercise(b);
  }
  for (final b in day.cooldown) {
    addExercise(b);
  }

  if (steps.isEmpty) {
    steps.add(
      SessionStep(
        kind: SessionStepKind.card,
        label: 'REST',
        seconds: restSeconds,
        stepNumber: 0,
        totalSteps: 0,
      ),
    );
  }

  return steps;
}

import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';

/// What kind of screen [SessionStep] renders as. Warmups, cooldowns, and
/// between-set rests all use the same "prep card" layout ([SessionStepKind.card]);
/// main exercises use the immersive full-bleed player ([SessionStepKind.player]).
enum SessionStepKind { card, player }

/// One atomic step in a workout day's session. The session controller walks
/// a flat list of these — each one owns its own countdown, label, and (for
/// [SessionStepKind.card] steps) an optional "next exercise" preview.
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

  /// Header shown above the countdown — "FIRST UP", "REST", "COOL DOWN", …
  final String label;

  final int seconds;

  /// 1-based position within the day (used for the "Step 3/30" caption).
  final int stepNumber;
  final int totalSteps;

  /// The exercise this step centres on. For a [SessionStepKind.card] warmup
  /// or cooldown, this is the exercise the user is doing. For a rest card,
  /// [nextBlock] carries the exercise coming next.
  final PlanBlock? block;
  final PlanBlock? nextBlock;
}

/// Expands a [PlanDay] into the ordered list of steps that make up its
/// session. Warmups → main (with rest cards between) → cooldowns. Each
/// exercise gets one step; rests are inserted only between main exercises.
List<SessionStep> buildSessionSteps({
  required PlanDay day,
  required int restSeconds,
}) {
  final steps = <SessionStep>[];
  final exerciseSteps = day.warmup.length + day.main.length + day.cooldown.length;
  var stepNo = 0;

  int secondsFor(PlanBlock b) {
    // Card steps run for the prescribed time when the block is timed, and
    // fall back to a sensible default for rep-based work (long enough to
    // finish the reps but not so long it feels padded).
    return b.unit == ExerciseUnit.seconds ? b.amount : 30;
  }

  for (var i = 0; i < day.warmup.length; i++) {
    final b = day.warmup[i];
    stepNo += 1;
    steps.add(SessionStep(
      kind: SessionStepKind.card,
      label: i == 0 ? 'FIRST UP' : 'WARM UP',
      seconds: secondsFor(b),
      stepNumber: stepNo,
      totalSteps: exerciseSteps,
      block: b,
    ));
  }

  // One rest card after every four main exercises — so a 12-exercise main
  // block sees rests before exercises 5 / 9 (2 rests in a 12-set day) and
  // scales up to 3 rests once the main block hits 16+ exercises. Change the
  // divisor here (kept as [restEvery]) if the cadence needs tuning again.
  const restEvery = 4;
  for (var i = 0; i < day.main.length; i++) {
    final b = day.main[i];
    if (i > 0 && i % restEvery == 0) {
      // Rest between blocks of main exercises — same card layout as warmups,
      // but the preview shows the exercise that is about to start.
      steps.add(SessionStep(
        kind: SessionStepKind.card,
        label: 'REST',
        seconds: restSeconds,
        stepNumber: stepNo,
        totalSteps: exerciseSteps,
        nextBlock: b,
      ));
    }
    stepNo += 1;
    final seconds =
        b.unit == ExerciseUnit.seconds ? b.amount : 45; // reps → 45s window
    steps.add(SessionStep(
      kind: SessionStepKind.player,
      label: b.unit == ExerciseUnit.seconds ? 'HOLD' : 'GO',
      seconds: seconds,
      stepNumber: stepNo,
      totalSteps: exerciseSteps,
      block: b,
    ));
  }

  for (var i = 0; i < day.cooldown.length; i++) {
    final b = day.cooldown[i];
    stepNo += 1;
    steps.add(SessionStep(
      kind: SessionStepKind.card,
      label: i == 0 ? 'COOL DOWN' : 'COOL DOWN',
      seconds: secondsFor(b),
      stepNumber: stepNo,
      totalSteps: exerciseSteps,
      block: b,
    ));
  }

  return steps;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/features/health/application/health_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise_lookup.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:military_calisthenics_women/features/workouts/application/progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/quit_feedback_service.dart';
import 'package:military_calisthenics_women/features/workouts/application/training_progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/workout_history_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/workout_settings_controller.dart';
import 'package:military_calisthenics_women/features/workouts/domain/session_step.dart';
import 'package:military_calisthenics_women/features/workouts/presentation/difficulty_adjust_screen.dart';
import 'package:military_calisthenics_women/features/workouts/presentation/mission_complete_modal.dart';
import 'package:military_calisthenics_women/features/workouts/presentation/quit_feedback_screen.dart';
import 'package:provider/provider.dart';

/// Walks the user through one day's full session: warmup cards → main-set
/// player (with rest cards between) → cooldown cards. Marks the day complete
/// and pops back to the home stack when the last step finishes.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.day});

  final PlanDay day;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late List<SessionStep> _steps;
  int _index = 0;

  /// Total duration of the current step in seconds. Grows when the user
  /// taps "+10s".
  double _totalSec = 0;

  /// Real-time elapsed seconds within the current step. Driven by [_ticker]
  /// at vsync rate so the progress bar can animate continuously instead of
  /// jumping once per second.
  double _elapsedSec = 0;
  Duration _lastTick = Duration.zero;
  bool _paused = false;
  late final Ticker _ticker;
  late final DateTime _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    final rest = context.read<WorkoutSettingsController>().restSeconds;
    _steps = buildSessionSteps(day: widget.day, restSeconds: rest);
    _ticker = createTicker(_onTick);
    _sessionStartedAt = DateTime.now();
    _startStep(0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startStep(int i) {
    if (i >= _steps.length) {
      _ticker.stop();
      _finish();
      return;
    }
    setState(() {
      _index = i;
      _totalSec = _steps[i].seconds.toDouble();
      _elapsedSec = 0;
      _paused = false;
      _lastTick = Duration.zero;
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration now) {
    if (_lastTick == Duration.zero) {
      _lastTick = now;
      return;
    }
    final delta = (now - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = now;
    if (_paused) return;
    final next = _elapsedSec + delta;
    if (next >= _totalSec) {
      _startStep(_index + 1);
      return;
    }
    setState(() => _elapsedSec = next);
  }

  int get _remaining => (_totalSec - _elapsedSec).ceil().clamp(0, 1 << 31);
  double get _stepProgress =>
      _totalSec == 0 ? 0.0 : (_elapsedSec / _totalSec).clamp(0.0, 1.0);

  void _skip() => _startStep(_index + 1);
  void _prev() => _startStep((_index - 1).clamp(0, _steps.length - 1));
  void _togglePause() => setState(() {
        _paused = !_paused;
        // Reset the tick reference so the paused span doesn't get counted
        // as elapsed time on the next tick after resume.
        _lastTick = Duration.zero;
      });
  void _addTen() => setState(() => _totalSec += 10);

  /// Training-tab days use a synthetic day index (10 000+) so we can tell
  /// them apart from 21-day mission days. Progress plumbing routes to the
  /// [TrainingProgressController] for training days and to the mission
  /// [ProgressController] for mission days.
  bool get _isTrainingDay => widget.day.dayIndex >= 10000;

  Future<void> _finish() async {
    _ticker.stop();
    if (!mounted) return;
    final progressCtrl = context.read<ProgressController>();
    final trainingCtrl = context.read<TrainingProgressController>();
    final historyCtrl = context.read<WorkoutHistoryController>();
    final dayIndex = widget.day.dayIndex;
    final WorkoutHistoryKind kind;
    if (dayIndex >= 20000) {
      kind = WorkoutHistoryKind.custom;
    } else if (dayIndex >= 10000) {
      kind = WorkoutHistoryKind.training;
    } else {
      kind = WorkoutHistoryKind.mission;
    }
    final finishedAt = DateTime.now();
    unawaited(historyCtrl.record(WorkoutHistoryEntry(
      id: '${finishedAt.microsecondsSinceEpoch}-$dayIndex',
      completedAt: finishedAt,
      title: widget.day.title,
      minutes: widget.day.estimatedMinutes,
      calories: widget.day.estimatedCalories,
      kind: kind,
      accentIndex: dayIndex,
    )));
    unawaited(context.read<HealthController>().logWorkout(
          start: _sessionStartedAt,
          end: finishedAt,
          activeEnergyKcal: widget.day.estimatedCalories.toDouble(),
        ));
    // Grab the root navigator now — the current [context] gets unmounted the
    // moment we popUntil, and we still need a live handle to show the
    // celebration modal on top of the home screen.
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (_isTrainingDay) {
      await trainingCtrl.clear(widget.day.dayIndex);
    } else {
      await progressCtrl.markDayCompleted(widget.day.dayIndex);
    }
    final starCount = progressCtrl.stars;
    // Pop the session AND the two intermediate screens (Calibration,
    // WorkoutDay detail) so the user lands back on the home mission list.
    rootNav.popUntil((route) => route.isFirst);
    if (_isTrainingDay) return;
    // Show the celebration directly rather than relying on the home screen
    // to notice the pending-celebration flag on its next rebuild — some
    // rebuild orderings after popUntil miss it. Home's postFrame trigger is
    // still there as a fallback for cold restarts.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = rootNav.context;
      await MissionCompleteModal.show(
        ctx,
        dayIndex: widget.day.dayIndex,
        starCount: starCount,
      );
      await progressCtrl.clearPendingCelebration();
    });
  }

  Future<bool> _confirmExit() async {
    // Pause the ticker while the sheet is up so the workout doesn't keep
    // counting down under the modal — resumed by [_startStep] if the user
    // decides to stay.
    final wasPaused = _paused;
    setState(() => _paused = true);

    final onboarding = context.read<OnboardingController>();
    final trainer = onboarding.answerFor<Trainer>('trainer') ?? Trainer.hailey;

    final result = await Navigator.of(context).push<QuitFeedbackResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QuitFeedbackScreen(trainer: trainer),
      ),
    );

    if (!mounted) return true;

    if (result == null || !result.leave) {
      setState(() {
        _paused = wasPaused;
        _lastTick = Duration.zero;
      });
      return false;
    }

    final reason = result.reason;
    if (reason != null && reason != QuitReason.justLook) {
      // Fire-and-forget — the user's flow must not wait on Firestore.
      unawaited(
        QuitFeedbackService().record(
          reason: reason,
          dayIndex: widget.day.dayIndex,
          stepLabel: _steps[_index].label,
          note: result.note,
        ),
      );
    }

    if (reason == QuitReason.tooHard || reason == QuitReason.tooEasy) {
      final direction = reason == QuitReason.tooHard ? -1 : 1;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DifficultyAdjustScreen(direction: direction),
        ),
      );
    }

    // Training-tab routines get their partial-completion snapshot saved
    // here so the routine card can offer a CONTINUE affordance next time.
    if (_isTrainingDay && mounted) {
      final total = _steps.isEmpty ? 1 : _steps.length;
      final pct = ((_index / total) * 100).round();
      await context.read<TrainingProgressController>().setPercent(
            widget.day.dayIndex,
            pct,
          );
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit()) {
          _ticker.stop();
          if (mounted) {
            // Quit flow lands the user back on the mission list, not on
            // the workout-detail page underneath, so a quit feels like a
            // real "back to home" rather than a half-step.
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        body: SafeArea(
          child: step.kind == SessionStepKind.card
              ? _CardView(
                  step: step,
                  remaining: _remaining,
                  hasPrev: _index > 0,
                  onSkip: _skip,
                  onPrev: _prev,
                  onAddTen: _addTen,
                  onExit: () async {
                    if (await _confirmExit()) {
                      _ticker.stop();
                      if (mounted) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    }
                  },
                )
              : _PlayerView(
                  step: step,
                  remaining: _remaining,
                  stepProgress: _stepProgress,
                  paused: _paused,
                  hasPrev: _index > 0,
                  onPrev: _prev,
                  onNext: _skip,
                  onTogglePause: _togglePause,
                  onExit: () async {
                    if (await _confirmExit()) {
                      _ticker.stop();
                      if (mounted) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    }
                  },
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CARD VIEW — warm-up / rest / cool-down
// ---------------------------------------------------------------------------

class _CardView extends StatelessWidget {
  const _CardView({
    required this.step,
    required this.remaining,
    required this.hasPrev,
    required this.onSkip,
    required this.onPrev,
    required this.onAddTen,
    required this.onExit,
  });

  final SessionStep step;
  final int remaining;
  final bool hasPrev;
  final VoidCallback onSkip;
  final VoidCallback onPrev;
  final VoidCallback onAddTen;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final displayBlock = step.block ?? step.nextBlock;
    final exercise =
        displayBlock == null ? null : findExercise(displayBlock.exerciseId);
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
              ),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          step.label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$mm:$ss',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 68,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              _AddTenChip(onTap: onAddTen),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasPrev) ...[
                _RoundActionButton(
                  icon: Icons.skip_previous_rounded,
                  filled: false,
                  onTap: onPrev,
                ),
                const SizedBox(width: 16),
              ],
              _PillButton(
                label: 'Skip',
                onTap: onSkip,
              ),
            ],
          ),
        ),
        const Spacer(),
        // Step caption + upcoming exercise preview (placeholder video).
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${step.stepNumber}/${step.totalSteps}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exercise?.name ?? 'Rest',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        _VideoPlaceholder(height: MediaQuery.of(context).size.height * 0.42),
      ],
    );
  }
}

class _AddTenChip extends StatelessWidget {
  const _AddTenChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '+10s',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon,
            color: filled ? Colors.white : const Color(0xFF0B111C), size: 26),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2A2A), Color(0xFF161616)],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline_rounded,
                color: Colors.white.withOpacity(0.35), size: 72),
            const SizedBox(height: 10),
            Text(
              'Demo video placeholder',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PLAYER VIEW — main exercises (full-bleed video)
// ---------------------------------------------------------------------------

class _PlayerView extends StatelessWidget {
  const _PlayerView({
    required this.step,
    required this.remaining,
    required this.stepProgress,
    required this.paused,
    required this.hasPrev,
    required this.onPrev,
    required this.onNext,
    required this.onTogglePause,
    required this.onExit,
  });

  final SessionStep step;
  final int remaining;

  /// Progress through the current exercise (0.0 → 1.0). Continuous, so the
  /// bottom control bar can fill smoothly instead of stepping once per
  /// second. The top dash bar uses [SessionStep.stepNumber] / [totalSteps]
  /// instead — it tracks the day, not the current exercise.
  final double stepProgress;
  final bool paused;
  final bool hasPrev;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTogglePause;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final exercise =
        step.block == null ? null : findExercise(step.block!.exerciseId);
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed placeholder for the exercise video.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2A2A2A),
                  const Color(0xFF1A1A1A),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          child: Center(
            child: Icon(Icons.play_circle_outline_rounded,
                color: Colors.white.withOpacity(0.12), size: 120),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 6),
            _DashProgressBar(
              filled: step.stepNumber,
              total: step.totalSteps,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _CircleGlyph(
                    icon: Icons.close_rounded,
                    onTap: onExit,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$mm:$ss',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 44,
                      height: 1,
                      letterSpacing: -1,
                      shadows: const [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exercise?.name ?? 'Exercise',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _BottomControlBar(
                progress: stepProgress,
                paused: paused,
                hasPrev: hasPrev,
                onPrev: onPrev,
                onNext: onNext,
                onTogglePause: onTogglePause,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dashed strip at the top of the player. One dash per exercise in the day
/// (warmups + main sets + cooldowns — rest cards are skipped), lit up to the
/// currently-active exercise. A dash flips on the moment its exercise
/// starts and stays lit for the rest of the day.
class _DashProgressBar extends StatelessWidget {
  const _DashProgressBar({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: LayoutBuilder(builder: (context, c) {
        final dashCount = total.clamp(1, 60);
        final gap = 4.0;
        final dashW = (c.maxWidth - (dashCount - 1) * gap) / dashCount;
        return Row(
          children: List.generate(dashCount, (i) {
            return Padding(
              padding: EdgeInsets.only(right: i == dashCount - 1 ? 0 : gap),
              child: Container(
                width: dashW,
                height: 6,
                decoration: BoxDecoration(
                  color: i < filled
                      ? Colors.white
                      : Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _CircleGlyph extends StatelessWidget {
  const _CircleGlyph({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _BottomControlBar extends StatelessWidget {
  const _BottomControlBar({
    required this.progress,
    required this.paused,
    required this.hasPrev,
    required this.onPrev,
    required this.onNext,
    required this.onTogglePause,
  });

  final double progress;
  final bool paused;
  final bool hasPrev;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final fillW = (w * progress.clamp(0.0, 1.0)).clamp(0.0, w);
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: fillW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: IconButton(
                        onPressed: hasPrev ? onPrev : null,
                        icon: Icon(
                          Icons.skip_previous_rounded,
                          color: hasPrev
                              ? Colors.black.withOpacity(0.85)
                              : Colors.black.withOpacity(0.3),
                          size: 30,
                        ),
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        onPressed: onTogglePause,
                        icon: Icon(
                          paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          color: Colors.black.withOpacity(0.85),
                          size: 32,
                        ),
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        onPressed: onNext,
                        icon: Icon(
                          Icons.skip_next_rounded,
                          color: Colors.black.withOpacity(0.85),
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

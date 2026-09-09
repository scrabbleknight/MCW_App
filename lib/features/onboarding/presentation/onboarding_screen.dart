import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/features/auth/presentation/login_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/application/plan_recommendation.dart';
import 'package:military_calisthenics_women/features/paywall/application/purchase_controller.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:military_calisthenics_women/features/plan/presentation/plan_preview_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/achievements_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/age_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/current_weight_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/best_shape_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/calibration_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/diet_type_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/dream_body_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/eating_habits_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/energized_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/energy_level_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/exercise_frequency_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/experience_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/fitness_level_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/flexibility_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/food_cravings_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/get_notified_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/height_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/main_reason_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/meals_per_day_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/physical_build_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/sleep_hours_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/stairs_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/scientific_plan_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/typical_day_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/upcoming_event_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/water_intake_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/weight_change_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/weight_gain_events_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/work_schedule_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_duration_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/workout_preferences_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/goal_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/pitch_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/squad_welcome_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/testimonials_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/welcome_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/wellness_profile_step.dart';
import 'package:provider/provider.dart';

/// Container for the onboarding flow. Holds one [PageView] with every step
/// as a child, and layers the [OnboardingScaffold] chrome (back button +
/// progress bar) on top of every step except the full-bleed welcome slide.
///
/// New steps slot in as extra entries in [_steps]; the chrome auto-scales.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  static const _pageDuration = Duration(milliseconds: 320);
  static const _pageCurve = Curves.easeOutCubic;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _stepCount) return;
    await _pageController.animateToPage(
      index,
      duration: _pageDuration,
      curve: _pageCurve,
    );
  }

  Future<void> _next() => _goTo(_index + 1);
  Future<void> _back() => _goTo(_index - 1);

  // ignore: unused_element
  Future<void> _finish() async {
    await context.read<OnboardingController>().markCompleted();
  }

  Widget _wellnessProfile(OnboardingController controller) {
    // Weight and height are collected on the two preceding steps. In
    // dev / hot-reload situations they may be null, so fall back to
    // neutral defaults rather than short-circuiting the flow (which
    // would fire markCompleted on every rebuild).
    final weight = controller.answerFor<WeightAnswer>('current_weight') ??
        const WeightAnswer(kg: 65, unit: WeightUnit.kg);
    final height = controller.answerFor<HeightAnswer>('height') ??
        const HeightAnswer(cm: 165, unit: HeightUnit.cm);
    final rec = buildPlanRecommendation(
      currentWeight: weight,
      height: height,
      ageBand: controller.answerFor<AgeBand>('age_band'),
      exerciseFrequency:
          controller.answerFor<ExerciseFrequency>('exercise_frequency'),
      goal: controller.answerFor<FitnessGoal>('goal'),
      duration: controller.answerFor<WorkoutDuration>('workout_duration'),
    );
    return WellnessProfileStep(recommendation: rec, onContinue: _next);
  }

  Widget _planPreview(OnboardingController controller) {
    // Same graceful defaults as the wellness / plan builders — should never
    // trip in normal flow, but keeps hot-reload from throwing.
    final currentWeight =
        controller.answerFor<WeightAnswer>('current_weight') ??
            const WeightAnswer(kg: 65, unit: WeightUnit.kg);
    final goalWeight = controller.answerFor<WeightAnswer>('goal_weight') ??
        const WeightAnswer(kg: 60, unit: WeightUnit.kg);
    final trainer = controller.answerFor<Trainer>('trainer') ?? Trainer.hailey;
    final rec = buildPlanRecommendation(
      currentWeight: currentWeight,
      height: controller.answerFor<HeightAnswer>('height') ??
          const HeightAnswer(cm: 165, unit: HeightUnit.cm),
      ageBand: controller.answerFor<AgeBand>('age_band'),
      exerciseFrequency:
          controller.answerFor<ExerciseFrequency>('exercise_frequency'),
      goal: controller.answerFor<FitnessGoal>('goal'),
      duration: controller.answerFor<WorkoutDuration>('workout_duration'),
    );
    return PlanPreviewStep(
      currentWeight: currentWeight,
      goalWeight: goalWeight,
      trainer: trainer,
      goal: controller.answerFor<FitnessGoal>('goal'),
      workoutDuration: controller.answerFor<WorkoutDuration>('workout_duration'),
      dailyCalorieTarget: rec.caloriesPerDay,
      onConfirm: _next,
      onFeelingChanged: (feeling) =>
          controller.setAnswer('pre_start_feeling', feeling),
    );
  }

  Widget _paywall(OnboardingController controller) {
    final purchases = context.read<PurchaseController>();
    return PaywallStep(
      onPurchase: (plan) async {
        final outcome = await purchases.purchase(plan);
        if (outcome == PurchaseOutcome.success) {
          controller.setAnswer('paywall_plan', plan);
          _next();
          return true;
        }
        return false;
      },
      onRestore: purchases.restore,
    );
  }

  Widget _calibration(OnboardingController controller) {
    // Every answer the plan-generator wants is pulled off the controller
    // here so the algorithm never has to know Provider exists. Any missing
    // answer just falls back to null and the generator handles the default.
    final weight = controller.answerFor<WeightAnswer>('current_weight');
    final height = controller.answerFor<HeightAnswer>('height');
    final rec = buildPlanRecommendation(
      currentWeight: weight ?? const WeightAnswer(kg: 65, unit: WeightUnit.kg),
      height: height ?? const HeightAnswer(cm: 165, unit: HeightUnit.cm),
      ageBand: controller.answerFor<AgeBand>('age_band'),
      exerciseFrequency:
          controller.answerFor<ExerciseFrequency>('exercise_frequency'),
      goal: controller.answerFor<FitnessGoal>('goal'),
      duration: controller.answerFor<WorkoutDuration>('workout_duration'),
    );
    final inputs = PlanInputs(
      weightKg: weight?.kg,
      heightCm: height?.cm,
      ageBand: controller.answerFor<AgeBand>('age_band'),
      goal: controller.answerFor<FitnessGoal>('goal'),
      fitnessLevel: controller.answerFor<FitnessLevel>('fitness_level'),
      exerciseFrequency:
          controller.answerFor<ExerciseFrequency>('exercise_frequency'),
      workoutDuration: controller.answerFor<WorkoutDuration>('workout_duration'),
      workoutPreference:
          controller.answerFor<WorkoutPreference>('workout_preferences'),
      trainer: controller.answerFor<Trainer>('trainer'),
      mainReason: controller.answerFor<MainReason>('main_reason'),
      upcomingEvent: controller.answerFor<UpcomingEvent>('upcoming_event'),
      dietType: controller.answerFor<DietType>('diet_type'),
      eatingHabits: controller.answerFor<Set<EatingHabit>>('eating_habits'),
      dailyCalorieTarget: rec.caloriesPerDay,
    );
    return CalibrationStep(
      inputs: inputs,
      onReady: (plan) {
        controller.setAnswer('plan', plan);
        _next();
      },
    );
  }

  Widget _scientificPlan(OnboardingController controller) {
    // The trainer step is required to reach this one in the normal flow;
    // in dev / hot-reload / test scenarios the answer might be null, so
    // fall back to a sensible default rather than short-circuiting the
    // flow (which would fire markCompleted on every rebuild).
    final trainer =
        controller.answerFor<Trainer>('trainer') ?? Trainer.hailey;
    return ScientificPlanStep(trainer: trainer, onStart: _next);
  }

  int get _stepCount => 41;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OnboardingController>();
    // Hide the top chrome on the opening welcome slide *and* on the
    // post-paywall squad-welcome reveal — both are full-bleed moments
    // where a back chevron / progress strip would break the mood.
    final hideChrome = _index == 0 || _index == _stepCount - 1;

    final pages = <Widget>[
      WelcomeStep(
        onContinue: _next,
        onLogIn: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      ),
      _StepBody(
        child: ExperienceStep(
          selected: controller.answerFor<PriorExperience>('prior_experience'),
          onAnswered: (answer) {
            controller.setAnswer('prior_experience', answer);
            _next();
          },
        ),
      ),
      _StepBody(child: PitchStep(onCompleted: _next)),
      _StepBody(
        child: AgeStep(
          selected: controller.answerFor<AgeBand>('age_band'),
          onSelected: (band) {
            controller.setAnswer('age_band', band);
            _next();
          },
        ),
      ),
      _StepBody(
        child: GoalStep(
          selected: controller.answerFor<FitnessGoal>('goal'),
          onAnswered: (goal) {
            controller.setAnswer('goal', goal);
            _next();
          },
        ),
      ),
      _StepBody(child: TestimonialsStep(onCompleted: _next)),
      _StepBody(
        child: AchievementsStep(
          initialSelection:
              controller.answerFor<Set<Achievement>>('achievements') ??
                  const {},
          onCompleted: (picks) {
            controller.setAnswer('achievements', picks);
            _next();
          },
        ),
      ),
      _StepBody(
        child: DreamBodyStep(
          selected: controller.answerFor<DreamBody>('dream_body'),
          onSelected: (body) {
            controller.setAnswer('dream_body', body);
            _next();
          },
        ),
      ),
      _StepBody(
        child: PhysicalBuildStep(
          selected: controller.answerFor<PhysicalBuild>('physical_build'),
          onSelected: (build) {
            controller.setAnswer('physical_build', build);
            _next();
          },
        ),
      ),
      _StepBody(
        child: WeightChangeStep(
          selected: controller.answerFor<WeightPattern>('weight_pattern'),
          onAnswered: (pattern) {
            controller.setAnswer('weight_pattern', pattern);
            _next();
          },
        ),
      ),
      _StepBody(
        child: BestShapeStep(
          selected: controller.answerFor<BestShape>('best_shape'),
          onAnswered: (shape) {
            controller.setAnswer('best_shape', shape);
            _next();
          },
        ),
      ),
      _StepBody(
        child: FlexibilityStep(
          selected: controller.answerFor<Flexibility>('flexibility'),
          onAnswered: (flex) {
            controller.setAnswer('flexibility', flex);
            _next();
          },
        ),
      ),
      _StepBody(
        child: FitnessLevelStep(
          initial: controller.answerFor<FitnessLevel>('fitness_level'),
          onCompleted: (level) {
            controller.setAnswer('fitness_level', level);
            _next();
          },
        ),
      ),
      _StepBody(
        child: StairsStep(
          selected: controller.answerFor<StairsFeel>('stairs'),
          onAnswered: (v) {
            controller.setAnswer('stairs', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: ExerciseFrequencyStep(
          selected:
              controller.answerFor<ExerciseFrequency>('exercise_frequency'),
          onAnswered: (v) {
            controller.setAnswer('exercise_frequency', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: EnergyLevelStep(
          selected: controller.answerFor<EnergyLevel>('energy_level'),
          onAnswered: (v) {
            controller.setAnswer('energy_level', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: TypicalDayStep(
          selected: controller.answerFor<TypicalDay>('typical_day'),
          onAnswered: (v) {
            controller.setAnswer('typical_day', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: WorkScheduleStep(
          selected: controller.answerFor<WorkSchedule>('work_schedule'),
          onAnswered: (v) {
            controller.setAnswer('work_schedule', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: WorkoutPreferencesStep(
          selected:
              controller.answerFor<WorkoutPreference>('workout_preferences'),
          onAnswered: (v) {
            controller.setAnswer('workout_preferences', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: WorkoutDurationStep(
          selected: controller.answerFor<WorkoutDuration>('workout_duration'),
          onAnswered: (v) {
            controller.setAnswer('workout_duration', v);
            _next();
          },
        ),
      ),
      _StepBody(child: EnergizedStep(onContinue: _next)),
      _StepBody(
        child: WaterIntakeStep(
          selected: controller.answerFor<WaterIntake>('water_intake'),
          onAnswered: (v) {
            controller.setAnswer('water_intake', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: SleepHoursStep(
          selected: controller.answerFor<SleepHours>('sleep_hours'),
          onAnswered: (v) {
            controller.setAnswer('sleep_hours', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: MealsPerDayStep(
          selected: controller.answerFor<MealsPerDay>('meals_per_day'),
          onAnswered: (v) {
            controller.setAnswer('meals_per_day', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: WeightGainEventsStep(
          initialSelection: controller
                  .answerFor<Set<WeightGainEvent>>('weight_gain_events') ??
              const {},
          onCompleted: (picks) {
            controller.setAnswer('weight_gain_events', picks);
            _next();
          },
        ),
      ),
      _StepBody(
        child: FoodCravingsStep(
          initialSelection:
              controller.answerFor<Set<FoodCraving>>('food_cravings') ??
                  const {},
          onCompleted: (picks) {
            controller.setAnswer('food_cravings', picks);
            _next();
          },
        ),
      ),
      _StepBody(
        child: EatingHabitsStep(
          initialSelection:
              controller.answerFor<Set<EatingHabit>>('eating_habits') ??
                  const {},
          onCompleted: (picks) {
            controller.setAnswer('eating_habits', picks);
            _next();
          },
        ),
      ),
      _StepBody(
        child: DietTypeStep(
          selected: controller.answerFor<DietType>('diet_type'),
          onAnswered: (v) {
            controller.setAnswer('diet_type', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: WeightPickerStep(
          question: "What's your current weight?",
          initial: controller.answerFor<WeightAnswer>('current_weight'),
          onCompleted: (v) {
            controller.setAnswer('current_weight', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: WeightPickerStep(
          question: "Got it! And what's your goal weight?",
          initial: controller.answerFor<WeightAnswer>('goal_weight'),
          onCompleted: (v) {
            controller.setAnswer('goal_weight', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: HeightStep(
          initial: controller.answerFor<HeightAnswer>('height'),
          onCompleted: (v) {
            controller.setAnswer('height', v);
            _next();
          },
        ),
      ),
      _StepBody(child: _wellnessProfile(controller)),
      _StepBody(
        child: MainReasonStep(
          selected: controller.answerFor<MainReason>('main_reason'),
          onAnswered: (v) {
            controller.setAnswer('main_reason', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: UpcomingEventStep(
          selected: controller.answerFor<UpcomingEvent>('upcoming_event'),
          onAnswered: (v) {
            controller.setAnswer('upcoming_event', v);
            _next();
          },
        ),
      ),
      _StepBody(
        child: TrainerPickStep(
          initial: controller.answerFor<Trainer>('trainer'),
          onCompleted: (v) {
            controller.setAnswer('trainer', v);
            _next();
          },
        ),
      ),
      _StepBody(child: _scientificPlan(controller)),
      _StepBody(
        child: GetNotifiedStep(
          onDecided: (granted) {
            controller.setAnswer('notifications_granted', granted);
            _next();
          },
        ),
      ),
      _StepBody(child: _calibration(controller)),
      _StepBody(child: _planPreview(controller)),
      _StepBody(child: _paywall(controller)),
      // Post-paywall "welcome to the squad" reveal. Full-bleed (no
      // _StepBody padding, no chrome) so the enlistment moment lands.
      SquadWelcomeStep(onDeploy: _finish),
    ];

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _index = index),
            children: pages,
          ),
          // Chrome layer for every non-welcome step. Pointer-transparent
          // outside the visible controls so it doesn't eat taps on the body.
          if (!hideChrome)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: _StepChrome(
                  progress: (_index + 1) / _stepCount,
                  onBack: _back,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps a non-welcome step's body in a SafeArea + top padding so its
/// content clears the [_StepChrome] strip above it.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
        child: child,
      ),
    );
  }
}

/// Draws only the top strip (back chevron + progress bar). Body area below
/// is a transparent [IgnorePointer] so PageView children stay interactive.
class _StepChrome extends StatelessWidget {
  const _StepChrome({required this.progress, required this.onBack});

  final double progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onBack,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: scheme.onSurface,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: OnboardingProgressBar(progress: progress)),
                ],
              ),
            ),
          ),
          const Expanded(child: IgnorePointer(child: SizedBox.expand())),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/fitness_level_step.dart';
import 'package:military_calisthenics_women/features/plan/application/plan_generator.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:provider/provider.dart';

/// Post-quit tweak screen. Reached when the user says the workout was "too
/// hard" or "too easy" — pre-selects the nudged level (down or up one rung)
/// but lets them re-pick before CONTINUE regenerates the plan.
class DifficultyAdjustScreen extends StatefulWidget {
  const DifficultyAdjustScreen({
    super.key,
    required this.direction,
  });

  /// -1 to nudge easier, +1 to nudge harder.
  final int direction;

  @override
  State<DifficultyAdjustScreen> createState() => _DifficultyAdjustScreenState();
}

class _DifficultyAdjustScreenState extends State<DifficultyAdjustScreen> {
  static const _specs = <(String, String)>[
    ('Newbie', 'Never trained before. We\'ll start you from the ground up.'),
    ('Beginner',
        'Simple movements, low intensity — built for gradual adaptation.'),
    ('Intermediate',
        'Challenging movements and intensity, good for strength building.'),
    ('Advanced', 'Peak reps, long holds, tough progressions. Bring the pain.'),
  ];

  int _index = 1;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = context.read<OnboardingController>();
    final current = controller.answerFor<FitnessLevel>('fitness_level') ??
        controller.answerFor<PlanInputs>('plan_inputs')?.fitnessLevel ??
        FitnessLevel.beginner;
    final nudged = (current.index + widget.direction)
        .clamp(0, FitnessLevel.values.length - 1);
    _index = nudged;
  }

  Future<void> _save() async {
    final controller = context.read<OnboardingController>();
    final level = FitnessLevel.values[_index];
    controller.setAnswer('fitness_level', level);
    final currentInputs =
        controller.answerFor<PlanInputs>('plan_inputs') ?? const PlanInputs();
    final updated = currentInputs.copyWith(fitnessLevel: level);
    controller.setAnswer('plan_inputs', updated);
    controller.setAnswer('plan', generatePlan(updated));
    await controller.persistPlanInputs(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _specs[_index];
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 30),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 4),
              Text(
                widget.direction < 0
                    ? 'Let\'s dial it back'
                    : 'Let\'s push harder',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.direction < 0
                    ? 'We\'ll drop the intensity a notch so the next session '
                        'feels sustainable.'
                    : 'We\'ll bump the intensity so the next session actually '
                        'earns the sweat.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 200,
                  child: _ChevronRank(activeCount: _index + 1),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                spec.$1,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  spec.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: const Color(0xFF3B82F6),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                  thumbColor: Colors.white,
                  overlayColor:
                      const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  activeTickMarkColor: Colors.white,
                  inactiveTickMarkColor:
                      Colors.white.withValues(alpha: 0.5),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                  tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  min: 0,
                  max: (_specs.length - 1).toDouble(),
                  divisions: _specs.length - 1,
                  value: _index.toDouble(),
                  onChanged: (v) => setState(() => _index = v.round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Newbie',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Advanced',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _save,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CONTINUE',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same chevron insignia as the onboarding fitness-level step — kept
/// in-file so this screen can render standalone without pulling in the
/// onboarding kit's step scaffolding.
class _ChevronRank extends StatelessWidget {
  const _ChevronRank({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChevronRankPainter(
        activeCount: activeCount,
        palette: context.palette,
      ),
    );
  }
}

class _ChevronRankPainter extends CustomPainter {
  _ChevronRankPainter({required this.activeCount, required this.palette});

  final int activeCount;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const chevronCount = 4;
    const gap = 10.0;
    final availH = size.height;
    final chevronH = (availH - gap * (chevronCount - 1)) / chevronCount;
    for (int i = 0; i < chevronCount; i++) {
      final rankFromBottom = i;
      final active = rankFromBottom < activeCount;
      final widthFraction = 0.55 + rankFromBottom * 0.15;
      final w = size.width * widthFraction;
      final centerX = size.width / 2;
      final top =
          availH - (rankFromBottom + 1) * chevronH - rankFromBottom * gap;
      final bottom = top + chevronH;
      final path = Path()
        ..moveTo(centerX - w / 2, bottom)
        ..lineTo(centerX, top)
        ..lineTo(centerX + w / 2, bottom);

      if (active) {
        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.glacier, palette.arctic],
        ).createShader(Rect.fromLTWH(centerX - w / 2, top, w, chevronH));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = palette.arctic.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..shader = gradient,
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = palette.hairline,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChevronRankPainter old) =>
      old.activeCount != activeCount || old.palette != palette;
}

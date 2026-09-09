import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum WeightUnit { kg, lbs }

/// Weight in kilograms. `unit` is a UI-only preference for how the ruler
/// and value are displayed; the stored value is always kg.
class WeightAnswer {
  const WeightAnswer({required this.kg, required this.unit});
  final double kg;
  final WeightUnit unit;

  WeightAnswer copyWith({double? kg, WeightUnit? unit}) =>
      WeightAnswer(kg: kg ?? this.kg, unit: unit ?? this.unit);
}

/// Ruler-picker for weight, with a kg/lbs toggle. Reused by both the
/// current-weight and goal-weight steps via [question] + [initial].
class WeightPickerStep extends StatefulWidget {
  const WeightPickerStep({
    super.key,
    required this.question,
    required this.initial,
    required this.onCompleted,
  });

  final String question;
  final WeightAnswer? initial;
  final ValueChanged<WeightAnswer> onCompleted;

  @override
  State<WeightPickerStep> createState() => _WeightPickerStepState();
}

class _WeightPickerStepState extends State<WeightPickerStep> {
  static const _kgPerLb = 0.45359237;

  late WeightAnswer _answer =
      widget.initial ?? const WeightAnswer(kg: 65, unit: WeightUnit.kg);

  double get _displayValue => _answer.unit == WeightUnit.kg
      ? _answer.kg
      : _answer.kg / _kgPerLb;

  void _onRulerChanged(double v) {
    final kg = _answer.unit == WeightUnit.kg ? v : v * _kgPerLb;
    setState(() => _answer = _answer.copyWith(kg: kg));
  }

  void _onUnitChanged(WeightUnit unit) {
    setState(() => _answer = _answer.copyWith(unit: unit));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final unitLabel = _answer.unit == WeightUnit.kg ? 'kg' : 'lbs';
    final display = _displayValue;
    // kg: 30-200 in 0.1 steps, majors every 10 (=1kg). lbs: 66-440 in 0.2
    // steps, majors every 5 (=1lb) — same "major = 1 unit" cadence.
    final isKg = _answer.unit == WeightUnit.kg;
    final min = isKg ? 30.0 : 66.0;
    final max = isKg ? 200.0 : 440.0;
    final step = isKg ? 0.1 : 0.2;
    final majorEvery = isKg ? 10 : 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.question,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: UnitToggle<WeightUnit>(
            value: _answer.unit,
            onChanged: _onUnitChanged,
            options: const [
              UnitToggleOption(value: WeightUnit.kg, label: 'kg'),
              UnitToggleOption(value: WeightUnit.lbs, label: 'lbs'),
            ],
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              display.toStringAsFixed(1),
              style: text.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                fontSize: 68,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                unitLabel,
                style: text.titleMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        HorizontalRuler(
          min: min,
          max: max,
          step: step,
          majorEvery: majorEvery,
          value: display,
          majorLabel: (v) => v.round().toString(),
          onChanged: _onRulerChanged,
        ),
        const Spacer(flex: 2),
        PrimaryCta(
          label: 'CONTINUE',
          onPressed: () => widget.onCompleted(_answer),
        ),
      ],
    );
  }
}

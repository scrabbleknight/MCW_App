import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';

enum HeightUnit { ft, cm }

class HeightAnswer {
  const HeightAnswer({required this.cm, required this.unit});
  final double cm;
  final HeightUnit unit;

  HeightAnswer copyWith({double? cm, HeightUnit? unit}) =>
      HeightAnswer(cm: cm ?? this.cm, unit: unit ?? this.unit);
}

/// Ruler-picker for height. Toggle switches between ft/in (major ticks per
/// foot, minor ticks per inch) and cm (major ticks every 10 cm).
class HeightStep extends StatefulWidget {
  const HeightStep({
    super.key,
    required this.initial,
    required this.onCompleted,
  });

  final HeightAnswer? initial;
  final ValueChanged<HeightAnswer> onCompleted;

  @override
  State<HeightStep> createState() => _HeightStepState();
}

class _HeightStepState extends State<HeightStep> {
  static const _cmPerInch = 2.54;

  late HeightAnswer _answer =
      widget.initial ?? const HeightAnswer(cm: 175, unit: HeightUnit.ft);

  void _onRulerChanged(double v) {
    final cm = _answer.unit == HeightUnit.cm ? v : v * _cmPerInch;
    setState(() => _answer = _answer.copyWith(cm: cm));
  }

  void _onUnitChanged(HeightUnit unit) {
    setState(() => _answer = _answer.copyWith(unit: unit));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isCm = _answer.unit == HeightUnit.cm;
    final min = isCm ? 100.0 : 48.0;
    final max = isCm ? 220.0 : 95.0;
    final step = 1.0;
    final majorEvery = isCm ? 10 : 12;
    final rulerValue = isCm ? _answer.cm : _answer.cm / _cmPerInch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How tall are you?',
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: UnitToggle<HeightUnit>(
            value: _answer.unit,
            onChanged: _onUnitChanged,
            options: const [
              UnitToggleOption(value: HeightUnit.ft, label: 'ft'),
              UnitToggleOption(value: HeightUnit.cm, label: 'cm'),
            ],
          ),
        ),
        const Spacer(),
        _HeightDisplay(unit: _answer.unit, cm: _answer.cm),
        const SizedBox(height: 16),
        HorizontalRuler(
          min: min,
          max: max,
          step: step,
          majorEvery: majorEvery,
          value: rulerValue,
          majorLabel: (v) =>
              isCm ? v.round().toString() : (v ~/ 12).toString(),
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

class _HeightDisplay extends StatelessWidget {
  const _HeightDisplay({required this.unit, required this.cm});

  final HeightUnit unit;
  final double cm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final large = text.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
      fontSize: 68,
      height: 1,
    );
    final unitStyle = text.titleMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.85),
      fontWeight: FontWeight.w600,
    );

    if (unit == HeightUnit.cm) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(cm.round().toString(), style: large),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('cm', style: unitStyle),
          ),
        ],
      );
    }

    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$feet', style: large),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('ft', style: unitStyle),
        ),
        const SizedBox(width: 14),
        Text('$inches', style: large),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('in', style: unitStyle),
        ),
      ],
    );
  }
}

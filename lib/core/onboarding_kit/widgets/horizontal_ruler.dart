import 'package:flutter/material.dart';

/// Horizontal scrolling ruler with a fixed center indicator.
///
/// Values are quantised in [step] units between [min] and [max]. Major ticks
/// (with numeric labels above them) appear every [majorEvery] step. The ruler
/// snaps to the nearest step at the end of a drag; the current value under
/// the center indicator is reported via [onChanged].
///
/// [value] is the *initial* position and is honoured on structural changes
/// (min/max/step, e.g. a unit toggle). It is deliberately NOT re-applied on
/// every parent rebuild — otherwise the parent's onChanged → setState →
/// rebuild cycle would fight the user's finger mid-drag.
class HorizontalRuler extends StatefulWidget {
  const HorizontalRuler({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.step,
    required this.majorEvery,
    required this.onChanged,
    required this.majorLabel,
    this.tickSpacing = 12.0,
    this.height = 84.0,
  });

  final double min;
  final double max;
  final double value;
  final double step;
  final int majorEvery;
  final ValueChanged<double> onChanged;
  final String Function(double majorValue) majorLabel;
  final double tickSpacing;
  final double height;

  @override
  State<HorizontalRuler> createState() => _HorizontalRulerState();
}

class _HorizontalRulerState extends State<HorizontalRuler> {
  late ScrollController _controller;
  bool _programmatic = false;
  int _lastReportedIndex = -1;

  int get _tickCount =>
      ((widget.max - widget.min) / widget.step).round() + 1;

  int _indexForValue(double v) =>
      ((v - widget.min) / widget.step).round().clamp(0, _tickCount - 1);

  @override
  void initState() {
    super.initState();
    final start = _indexForValue(widget.value);
    _lastReportedIndex = start;
    _controller = ScrollController(
      initialScrollOffset: start * widget.tickSpacing,
    );
    _controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant HorizontalRuler old) {
    super.didUpdateWidget(old);
    // Only reposition on structural range changes (unit swap). Ignoring
    // widget.value changes prevents fighting the user's active drag.
    final rangeChanged = widget.min != old.min ||
        widget.max != old.max ||
        widget.step != old.step;
    if (!rangeChanged) return;

    final target = _indexForValue(widget.value) * widget.tickSpacing;
    _lastReportedIndex = _indexForValue(widget.value);
    if (!_controller.hasClients) return;
    if ((_controller.offset - target).abs() < 0.5) return;

    _programmatic = true;
    _controller
        .animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _programmatic = false);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_programmatic) return;
    final index = (_controller.offset / widget.tickSpacing)
        .round()
        .clamp(0, _tickCount - 1);
    if (index == _lastReportedIndex) return;
    _lastReportedIndex = index;
    widget.onChanged(widget.min + index * widget.step);
  }

  void _snap() {
    final index = (_controller.offset / widget.tickSpacing)
        .round()
        .clamp(0, _tickCount - 1);
    final target = index * widget.tickSpacing;
    if ((_controller.offset - target).abs() < 0.5) return;
    _programmatic = true;
    _controller
        .animateTo(
          target,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
      _programmatic = false;
      if (index != _lastReportedIndex) {
        _lastReportedIndex = index;
        widget.onChanged(widget.min + index * widget.step);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth / 2;
        return SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollEndNotification && !_programmatic) _snap();
                  return false;
                },
                child: ListView.builder(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemExtent: widget.tickSpacing,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  itemCount: _tickCount,
                  itemBuilder: (context, i) {
                    final isMajor = i % widget.majorEvery == 0;
                    final label = isMajor
                        ? widget.majorLabel(widget.min + i * widget.step)
                        : null;
                    return _Tick(
                      isMajor: isMajor,
                      label: label,
                      color: scheme.onSurface,
                    );
                  },
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: 3,
                  height: 46,
                  margin: const EdgeInsets.only(top: 22),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({
    required this.isMajor,
    required this.label,
    required this.color,
  });

  final bool isMajor;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 20,
          // OverflowBox lets the numeric label render at its natural width
          // even when it's wider than the tick's own itemExtent slot.
          child: label == null
              ? null
              : OverflowBox(
                  maxWidth: 60,
                  minWidth: 0,
                  alignment: Alignment.center,
                  child: Text(
                    label!,
                    maxLines: 1,
                    softWrap: false,
                    style: text.bodySmall?.copyWith(
                      color: color.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 2),
        Container(
          width: isMajor ? 2 : 1,
          height: isMajor ? 26 : 14,
          color: color.withValues(alpha: isMajor ? 0.85 : 0.35),
        ),
      ],
    );
  }
}

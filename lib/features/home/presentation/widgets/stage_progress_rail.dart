import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

/// Left-hand vertical timeline that a day card sits next to. Renders a
/// short vertical bar with a node — hollow for locked days, filled for
/// completed, glowing for the active day.
class StageProgressRail extends StatelessWidget {
  const StageProgressRail({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.isActive,
    required this.isCompleted,
    required this.child,
  });

  final bool isFirst;
  final bool isLast;
  final bool isActive;
  final bool isCompleted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: CustomPaint(
              painter: _RailPainter(
                isFirst: isFirst,
                isLast: isLast,
                isActive: isActive,
                isCompleted: isCompleted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.isFirst,
    required this.isLast,
    required this.isActive,
    required this.isCompleted,
  });

  final bool isFirst;
  final bool isLast;
  final bool isActive;
  final bool isCompleted;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final nodeY = 50.0.clamp(20.0, size.height - 20);

    final linePaint = Paint()
      ..color = TacticalPalette.hairline
      ..strokeWidth = 2;

    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, nodeY - 10),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, nodeY + 10),
        Offset(centerX, size.height),
        linePaint,
      );
    }

    // Node — outer ring + inner fill for completed/active.
    final ringColor = isActive
        ? TacticalPalette.arctic
        : isCompleted
            ? TacticalPalette.arcticSoft
            : TacticalPalette.hairline;
    final ringPaint = Paint()
      ..color = ringColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(centerX, nodeY), 7, ringPaint);

    if (isActive) {
      final glow = Paint()
        ..color = TacticalPalette.arctic.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(centerX, nodeY), 10, glow);
      final fill = Paint()..color = TacticalPalette.arctic;
      canvas.drawCircle(Offset(centerX, nodeY), 4, fill);
    } else if (isCompleted) {
      final fill = Paint()..color = TacticalPalette.arcticSoft;
      canvas.drawCircle(Offset(centerX, nodeY), 4, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) =>
      old.isActive != isActive || old.isCompleted != isCompleted;
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Full-bleed camouflage backdrop — deterministic organic blobs painted onto
/// [base] using the tones in [patches].
///
/// Colour-family agnostic (blue arctic, olive, tan, urban, etc.) — pass the
/// colour set for the product. Ships as a static pattern with a fixed [seed]
/// so hot reloads don't reshuffle the shapes on you.
///
/// The blobs are irregular polygons, not perfect ovals, so the pattern reads
/// as real disruptive-pattern camouflage rather than confetti.
class CamoBackground extends StatelessWidget {
  const CamoBackground({
    super.key,
    required this.base,
    required this.patches,
    this.density = 60,
    this.seed = 42,
  });

  final Color base;
  final List<Color> patches;

  /// Approximate number of blobs painted. Higher = busier pattern.
  final int density;

  /// Seed for the random placement — change for a different arrangement.
  final int seed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CamoPainter(
          base: base,
          patches: patches,
          density: density,
          seed: seed,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CamoPainter extends CustomPainter {
  _CamoPainter({
    required this.base,
    required this.patches,
    required this.density,
    required this.seed,
  });

  final Color base;
  final List<Color> patches;
  final int density;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    if (patches.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final rand = math.Random(seed);

    // Two passes: bigger foundational shapes first, then smaller overlays for
    // the classic multi-scale disruptive-pattern look.
    _paintPass(
      canvas: canvas,
      rand: rand,
      bounds: Size(w, h),
      count: density ~/ 2,
      minRadius: 90,
      maxRadius: 180,
      irregularity: 0.45,
    );
    _paintPass(
      canvas: canvas,
      rand: rand,
      bounds: Size(w, h),
      count: density,
      minRadius: 30,
      maxRadius: 90,
      irregularity: 0.55,
    );
  }

  void _paintPass({
    required Canvas canvas,
    required math.Random rand,
    required Size bounds,
    required int count,
    required double minRadius,
    required double maxRadius,
    required double irregularity,
  }) {
    for (int i = 0; i < count; i++) {
      final color = patches[rand.nextInt(patches.length)];
      final cx = rand.nextDouble() * (bounds.width + 260) - 130;
      final cy = rand.nextDouble() * (bounds.height + 260) - 130;
      final radius = minRadius + rand.nextDouble() * (maxRadius - minRadius);

      final path = _organicBlobPath(
        center: Offset(cx, cy),
        radius: radius,
        rand: rand,
        irregularity: irregularity,
      );

      canvas.drawPath(path, Paint()..color = color);
    }
  }

  /// Closed path built from ~10 radial points, each nudged in/out to keep the
  /// silhouette organic and non-circular. Adjacent points join with a smooth
  /// quadratic curve so the outline reads as a natural blob.
  Path _organicBlobPath({
    required Offset center,
    required double radius,
    required math.Random rand,
    required double irregularity,
  }) {
    const points = 10;
    final vertices = <Offset>[];
    for (int i = 0; i < points; i++) {
      final angle = (i / points) * math.pi * 2;
      final jitter = 1.0 + (rand.nextDouble() * 2 - 1) * irregularity;
      final r = radius * jitter;
      vertices.add(Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r * (0.75 + rand.nextDouble() * 0.5),
      ));
    }

    final path = Path();
    path.moveTo(vertices.first.dx, vertices.first.dy);
    for (int i = 0; i < vertices.length; i++) {
      final curr = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      final mid = Offset((curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2);
      path.quadraticBezierTo(curr.dx, curr.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _CamoPainter old) {
    return old.base != base ||
        !listEquals(old.patches, patches) ||
        old.density != density ||
        old.seed != seed;
  }
}

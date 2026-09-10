import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:military_calisthenics_women/features/workouts/presentation/session_screen.dart';

/// Two-phase pre-workout screen. Phase 1 runs a fake "calibration" progress
/// ring (0 → 100%) with a "Generating your daily routine…" caption. When the
/// ring fills, the screen swaps to phase 2: a big "GET READY" title with
/// "Tap to Begin" pinned to the bottom. Both phases render on the same
/// [Scaffold] so the back button and dark ground stay stable.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.day});

  final PlanDay day;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _controller.value >= 1.0;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
            Center(
              child: done ? const _GetReady() : _Calibrating(value: _controller.value),
            ),
            if (done)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => SessionScreen(day: widget.day),
                      ),
                    ),
                    child: Text(
                      'Tap to Begin',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            if (done)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(day: widget.day),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Calibrating extends StatelessWidget {
  const _Calibrating({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 190,
                height: 190,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 9,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF7BAA3F),
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 52,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Generating your daily routine…',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GetReady extends StatelessWidget {
  const _GetReady();

  @override
  Widget build(BuildContext context) {
    return Text(
      'GET READY',
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 56,
        letterSpacing: 3,
        height: 1,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise_lookup.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:military_calisthenics_women/features/workouts/presentation/session_screen.dart';
import 'package:video_player/video_player.dart';

/// Two-phase pre-workout screen. Phase 1 preloads the day's exercise videos
/// while the progress ring fills. When loading finishes, the screen swaps to
/// phase 2: a big "GET READY" title with "Tap to Begin" pinned to the bottom.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.day});

  final PlanDay day;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final Map<String, VideoPlayerController> _preloadedControllers =
      <String, VideoPlayerController>{};
  double _progress = 0;
  bool _ready = false;
  bool _releasedControllers = false;

  @override
  void initState() {
    super.initState();
    _preloadVideos();
  }

  @override
  void dispose() {
    if (!_releasedControllers) {
      for (final controller in _preloadedControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  List<String> _videoUrls() {
    final urls = <String>[];
    final seen = <String>{};
    for (final block in widget.day.blocks) {
      final url = findExercise(block.exerciseId)?.videoAsset;
      if (url == null || url.isEmpty || !seen.add(url)) continue;
      urls.add(url);
    }
    return urls;
  }

  Future<void> _preloadVideos() async {
    final urls = _videoUrls();
    if (urls.isEmpty) {
      if (mounted) {
        setState(() {
          _progress = 1;
          _ready = true;
        });
      }
      return;
    }

    for (var i = 0; i < urls.length; i += 1) {
      final url = urls[i];
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        await controller.play();
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await controller.pause();
        await controller.seekTo(Duration.zero);
        _preloadedControllers[url] = controller;
      } catch (_) {
        await controller.dispose();
      }

      if (!mounted) return;
      setState(() => _progress = (i + 1) / urls.length);
    }

    if (!mounted) return;
    setState(() => _ready = true);
  }

  void _beginSession() {
    _releasedControllers = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          day: widget.day,
          preloadedVideoControllers: _preloadedControllers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.abyss,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: palette.chalk,
                  size: 30,
                ),
              ),
            ),
            Center(
              child: _ready
                  ? const _GetReady()
                  : _Calibrating(value: _progress),
            ),
            if (_ready)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _beginSession,
                    child: Text(
                      'Tap to Begin',
                      style: TextStyle(
                        color: palette.chalk.withValues(alpha: 0.85),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            if (_ready)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _beginSession,
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
    final palette = context.palette;
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
                  backgroundColor: palette.muted.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF7BAA3F),
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: GoogleFonts.plusJakartaSans(
                  color: palette.chalk,
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
            color: palette.chalk.withValues(alpha: 0.9),
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
    final palette = context.palette;
    return Text(
      'GET READY',
      style: GoogleFonts.plusJakartaSans(
        color: palette.chalk,
        fontWeight: FontWeight.w900,
        fontSize: 56,
        letterSpacing: 3,
        height: 1,
      ),
    );
  }
}

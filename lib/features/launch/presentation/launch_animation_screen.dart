import 'dart:async';

import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:video_player/video_player.dart';

/// One-shot intro video shown on cold app launch.
///
/// Plays the [assetPath] full-screen (BoxFit.cover), fires [onComplete] when
/// the clip finishes, and lets the viewer tap anywhere to skip early. If the
/// video can't be loaded (bad asset, decode failure) it fails open — waits
/// [fallbackDuration] then completes so a broken intro never traps the user.
class LaunchAnimationScreen extends StatefulWidget {
  const LaunchAnimationScreen({
    super.key,
    required this.assetPath,
    required this.onComplete,
    this.fallbackDuration = const Duration(seconds: 3),
  });

  final String assetPath;
  final VoidCallback onComplete;
  final Duration fallbackDuration;

  @override
  State<LaunchAnimationScreen> createState() => _LaunchAnimationScreenState();
}

class _LaunchAnimationScreenState extends State<LaunchAnimationScreen> {
  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _completed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.asset(widget.assetPath);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.addListener(_onTick);
      await controller.setVolume(0);
      await controller.play();
      setState(() => _ready = true);
    } catch (error) {
      debugPrint('LaunchAnimationScreen: video failed to load — $error');
      _fallbackTimer = Timer(widget.fallbackDuration, _complete);
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || _completed) return;
    if (c.value.hasError) {
      _complete();
      return;
    }
    if (c.value.isInitialized &&
        c.value.duration > Duration.zero &&
        c.value.position >= c.value.duration) {
      _complete();
    }
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    _fallbackTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showVideo = _ready && controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: context.palette.abyss,
      body: GestureDetector(
        onTap: _complete,
        behavior: HitTestBehavior.opaque,
        child: showVideo
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

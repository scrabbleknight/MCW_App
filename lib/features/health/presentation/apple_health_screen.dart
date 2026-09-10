import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/health/application/health_controller.dart';
import 'package:provider/provider.dart';

class AppleHealthScreen extends StatelessWidget {
  const AppleHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthController>();

    return Scaffold(
      backgroundColor: context.palette.abyss,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Apple Health',
          style: TextStyle(
            color: context.palette.chalk,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Connect to the Health App',
                    style: TextStyle(
                      color: context.palette.chalk,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (health.busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: health.connected,
                    activeColor: context.palette.arctic,
                    onChanged: (v) => _onToggle(context, v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Why connect to the Health App?',
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.hairline),
            ),
            child: Column(
              children: [
                _Reason(
                  icon: Icons.bolt_rounded,
                  text:
                      'Sync your workout data to the Health app where they will '
                      'appear as part of your daily activity.',
                ),
                Divider(height: 1, color: context.palette.hairline),
                _Reason(
                  icon: Icons.local_fire_department_rounded,
                  text:
                      'Keep track of your workout time, weight changes, and '
                      'calories burned.',
                ),
                Divider(height: 1, color: context.palette.hairline),
                _Reason(
                  icon: Icons.favorite_rounded,
                  text:
                      'Tracking your workouts will help you achieve your '
                      'fitness goals faster.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AppTile(
                color: Colors.white,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF375F),
                  size: 44,
                ),
              ),
              const SizedBox(width: 22),
              Icon(
                Icons.swap_horiz_rounded,
                color: context.palette.chalk,
                size: 32,
              ),
              const SizedBox(width: 22),
              _AppTile(
                color: context.palette.surfaceHigh,
                padding: EdgeInsets.zero,
                child: Image.asset(
                  'assets/branding/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onToggle(BuildContext context, bool value) async {
    final health = context.read<HealthController>();
    final ok = await health.setConnected(value);
    if (!context.mounted) return;
    if (value && !ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text(
            'Health access was declined. Enable it in Settings → Health → Data Access.',
          ),
        ));
    }
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF6B8E23),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.palette.chalk,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(0),
  });

  final Color color;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Center(child: child),
      ),
    );
  }
}

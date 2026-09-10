import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Celebration modal shown on the home screen after a workout day finishes.
/// Anchored to the mission-list view (not the workout screen) so the user
/// lands back at their plan with the star sitting on top of it. Card echoes
/// the arctic-blue theme: dark ground with a soft blue vignette, gold star
/// bursting at the top, blue CTA at the bottom.
class MissionCompleteModal extends StatelessWidget {
  const MissionCompleteModal({
    super.key,
    required this.dayIndex,
    required this.starCount,
    required this.onContinue,
  });

  final int dayIndex;
  final int starCount;
  final VoidCallback onContinue;

  static Future<void> show(
    BuildContext context, {
    required int dayIndex,
    required int starCount,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (ctx) => MissionCompleteModal(
        dayIndex: dayIndex,
        starCount: starCount,
        onContinue: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = starCount == 1;
    final title = isFirst ? 'First Mission Complete' : 'Mission Complete';
    final pill = isFirst
        ? 'You got your first star.'
        : 'You earned another star.';
    final body = isFirst
        ? 'You completed your first workout and took the first real step in '
            'your 21-day mission. Keep going — your next mission is waiting.'
        : 'Day $dayIndex is in the books. That\'s $starCount stars on the '
            'board. Keep the streak alive — your next mission is waiting.';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 130, 24, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF141C2B), Color(0xFF0B111C)],
              ),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.55),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.30),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pill,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6FA8DC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                _ContinueButton(onTap: onContinue),
              ],
            ),
          ),
          // Star burst: soft radial glow behind, then the badge image.
          // Lifted well above the title so the shine rays clear the top of
          // the card and read as a spotlight beam over the modal.
          Positioned(
            top: -90,
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFF5B840).withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/branding/gold_star.png',
                    width: 190,
                    height: 190,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF5B840),
                      size: 190,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF1D5FD1), Color(0xFF3B82F6)],
          ),
          border: Border.all(
            color: const Color(0xFFB6D3F1).withOpacity(0.55),
          ),
        ),
        child: Text(
          'CONTINUE MY MISSION',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/fitness_level_step.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';
import 'package:military_calisthenics_women/features/workouts/application/session_feedback_service.dart';

/// Result the caller acts on after the celebration/feedback sheet closes.
/// The submit path returns the picked mood + tags + note; the X button
/// returns a "dismissed" result so the caller can still route home.
class SessionCompleteResult {
  const SessionCompleteResult({
    required this.submitted,
    this.mood,
    this.tags = const [],
    this.note,
  });
  final bool submitted;
  final SessionMood? mood;
  final List<SessionTag> tags;
  final String? note;
}

/// Shown immediately after the last step of a session finishes. Congratulates
/// the user in-character (per their picked trainer), summarises the session
/// stats, then invites them to log a mood + tags + optional note. Blue theme,
/// mirrors [QuitFeedbackScreen] so the two feel like a matched pair.
class SessionCompleteScreen extends StatefulWidget {
  const SessionCompleteScreen({
    super.key,
    required this.trainer,
    required this.title,
    required this.minutes,
    required this.calories,
    this.fitnessLevel,
  });

  final Trainer trainer;
  final String title;
  final int minutes;
  final int calories;
  final FitnessLevel? fitnessLevel;

  @override
  State<SessionCompleteScreen> createState() => _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends State<SessionCompleteScreen> {
  SessionMood? _mood;
  final Set<SessionTag> _tags = {};
  final TextEditingController _noteCtrl = TextEditingController();
  static const _maxChars = 500;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _primaryBubble => switch (widget.trainer) {
    Trainer.hailey => 'Give yourself\na clap.',
    Trainer.gemma => 'Take a moment.\nYou earned it.',
    Trainer.amy => 'Chin up,\nchampion.',
  };

  String get _secondaryBubble => switch (widget.trainer) {
    Trainer.hailey => 'Awesome job!',
    Trainer.gemma => 'Proud of you!',
    Trainer.amy => 'Legendary!',
  };

  String? get _moodQuote {
    final trainer = widget.trainer;
    return switch ((_mood, trainer)) {
      (null, _) => null,
      (SessionMood.rough, Trainer.hailey) =>
        '"That was a proper grind — respect."',
      (SessionMood.rough, Trainer.gemma) =>
        '"Rough one — you showed up anyway."',
      (SessionMood.rough, Trainer.amy) => '"Tough day, tougher recruit."',
      (SessionMood.okay, Trainer.hailey) => '"It felt good, just right."',
      (SessionMood.okay, Trainer.gemma) => '"Nice, steady work."',
      (SessionMood.okay, Trainer.amy) => '"Locked in and on target."',
      (SessionMood.great, Trainer.hailey) => '"You felt strong out there!"',
      (SessionMood.great, Trainer.gemma) => '"Absolutely flying today!"',
      (SessionMood.great, Trainer.amy) => '"That was a masterclass."',
    };
  }

  String get _levelLabel {
    return switch (widget.fitnessLevel) {
      FitnessLevel.newbie => 'Newbie',
      FitnessLevel.beginner => 'Beginner',
      FitnessLevel.intermediate => 'Intermediate',
      FitnessLevel.advanced => 'Advanced',
      null => 'Standard',
    };
  }

  void _submit() {
    final mood = _mood;
    if (mood == null) return;
    final note = _noteCtrl.text.trim();
    Navigator.of(context).pop(
      SessionCompleteResult(
        submitted: true,
        mood: mood,
        tags: _tags.toList(),
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.abyss,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(
                  const SessionCompleteResult(submitted: false),
                ),
                icon: Icon(
                  Icons.close_rounded,
                  color: palette.chalk,
                  size: 28,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroBlock(
                      trainer: widget.trainer,
                      primaryText: _primaryBubble,
                      secondaryText: _secondaryBubble,
                      minutes: widget.minutes,
                      levelLabel: _levelLabel,
                      calories: widget.calories,
                    ),
                    const SizedBox(height: 20),
                    _MoodRow(
                      selected: _mood,
                      onChanged: (m) => setState(() => _mood = m),
                    ),
                    const SizedBox(height: 16),
                    _MoodQuotePill(text: _moodQuote),
                    const SizedBox(height: 22),
                    _TagChips(
                      selected: _tags,
                      onToggle: (t) => setState(() {
                        if (!_tags.add(t)) _tags.remove(t);
                      }),
                    ),
                    const SizedBox(height: 22),
                    _NoteField(controller: _noteCtrl, maxChars: _maxChars),
                    const SizedBox(height: 20),
                    _SubmitButton(
                      enabled: _mood != null,
                      onTap: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HERO — trainer cutout + speech bubbles + stat chips overlay
// ---------------------------------------------------------------------------

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.trainer,
    required this.primaryText,
    required this.secondaryText,
    required this.minutes,
    required this.levelLabel,
    required this.calories,
  });

  final Trainer trainer;
  final String primaryText;
  final String secondaryText;
  final int minutes;
  final String levelLabel;
  final int calories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: -20,
            bottom: 0,
            width: 260,
            child: Image.asset(
              trainer.cutoutAsset,
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: Color(0xFF3B82F6),
                size: 120,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 0,
            child: _SpeechBubble(text: primaryText),
          ),
          Positioned(
            top: 180,
            left: 0,
            child: _StatsColumn(
              minutes: minutes,
              levelLabel: levelLabel,
              calories: calories,
            ),
          ),
          Positioned(
            top: 230,
            right: 4,
            child: _SpeechBubble(text: secondaryText, compact: true),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, this.compact = false});
  final String text;
  final bool compact;

  static const _accent = Color(0xFF2563EB);
  static const _glow = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 200 : 240),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 20,
          vertical: compact ? 14 : 18,
        ),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _glow, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: _glow.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: palette.chalk,
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _StatsColumn extends StatelessWidget {
  const _StatsColumn({
    required this.minutes,
    required this.levelLabel,
    required this.calories,
  });
  final int minutes;
  final String levelLabel;
  final int calories;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatChip(
          icon: Icons.access_time_rounded,
          label: '$minutes Mins',
          iconColor: const Color(0xFF60A5FA),
        ),
        const SizedBox(height: 10),
        _StatChip(
          icon: Icons.bolt_rounded,
          label: levelLabel,
          iconColor: const Color(0xFF93C5FD),
        ),
        const SizedBox(height: 10),
        _StatChip(
          icon: Icons.local_fire_department_rounded,
          label: '$calories Kcal',
          iconColor: const Color(0xFFF97373),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.iconColor,
  });
  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceHigh.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: palette.chalk,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MOOD + TAGS + NOTE + SUBMIT
// ---------------------------------------------------------------------------

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.selected, required this.onChanged});
  final SessionMood? selected;
  final ValueChanged<SessionMood> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _MoodBubble(
          emoji: '🙁',
          isSelected: selected == SessionMood.rough,
          onTap: () => onChanged(SessionMood.rough),
        ),
        _MoodBubble(
          emoji: '😐',
          isSelected: selected == SessionMood.okay,
          onTap: () => onChanged(SessionMood.okay),
        ),
        _MoodBubble(
          emoji: '🙂',
          isSelected: selected == SessionMood.great,
          onTap: () => onChanged(SessionMood.great),
        ),
      ],
    );
  }
}

class _MoodBubble extends StatelessWidget {
  const _MoodBubble({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surfaceHigh,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}

class _MoodQuotePill extends StatelessWidget {
  const _MoodQuotePill({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox(height: 40);
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text!,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF93C5FD),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChips extends StatelessWidget {
  const _TagChips({required this.selected, required this.onToggle});
  final Set<SessionTag> selected;
  final ValueChanged<SessionTag> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final tag in SessionTag.values)
          _TagChip(
            label: tag.displayLabel,
            isSelected: selected.contains(tag),
            onTap: () => onToggle(tag),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.18)
              : palette.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: palette.chalk,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({required this.controller, required this.maxChars});
  final TextEditingController controller;
  final int maxChars;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final len = widget.controller.text.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.controller,
            maxLines: 4,
            maxLength: widget.maxChars,
            style: TextStyle(color: palette.chalk, fontSize: 15),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: 'Please give your suggestions to help us become better.',
              hintStyle: TextStyle(color: palette.muted, fontSize: 15),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$len/${widget.maxChars}',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF2563EB) : palette.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'SUBMIT',
          style: GoogleFonts.plusJakartaSans(
            color: enabled
                ? Colors.white
                : palette.chalk.withValues(alpha: 0.4),
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}

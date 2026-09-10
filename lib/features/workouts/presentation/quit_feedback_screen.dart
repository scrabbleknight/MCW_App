import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/trainer_pick_step.dart';
import 'package:military_calisthenics_women/features/workouts/application/quit_feedback_service.dart';

/// Result the user picks in the quit-feedback sheet — the caller uses this
/// to decide whether to pop the session (and whether to route through the
/// difficulty-adjust screen on the way out).
class QuitFeedbackResult {
  const QuitFeedbackResult({required this.leave, this.reason, this.note});
  final bool leave;
  final QuitReason? reason;
  final String? note;
}

/// Sheet shown when the user taps X on the session player. Trainer cutout
/// on the left, in-character chat bubble asking what's up, chip options,
/// optional free-text feedback. Submit → the caller handles routing +
/// Firestore write; Back closes the sheet without leaving the workout.
class QuitFeedbackScreen extends StatefulWidget {
  const QuitFeedbackScreen({super.key, required this.trainer});

  final Trainer trainer;

  @override
  State<QuitFeedbackScreen> createState() => _QuitFeedbackScreenState();
}

class _QuitFeedbackScreenState extends State<QuitFeedbackScreen> {
  QuitReason? _selected;
  final TextEditingController _noteCtrl = TextEditingController();
  static const _maxChars = 500;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _bubbleText => switch (widget.trainer) {
        Trainer.hailey =>
          "Hey, what's going on? Something not feeling right?",
        Trainer.gemma =>
          "Hey — bailing already? Tell me what's off and I'll fix it.",
        Trainer.amy =>
          "Talk to me. What's making you want to bounce?",
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(
                    const QuitFeedbackResult(leave: false),
                  ),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 4),
              _TrainerBubbleRow(
                trainer: widget.trainer,
                bubbleText: _bubbleText,
              ),
              const SizedBox(height: 22),
              Text(
                'This helps us get to know you and find the perfect workout for you!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              _ReasonChips(
                selected: _selected,
                onChanged: (r) => setState(() => _selected = r),
              ),
              const SizedBox(height: 22),
              _NoteField(controller: _noteCtrl, maxChars: _maxChars),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'BACK',
                      filled: false,
                      onTap: () => Navigator.of(context).pop(
                        const QuitFeedbackResult(leave: false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _ActionButton(
                      label: 'SUBMIT',
                      filled: true,
                      enabled: _selected != null,
                      onTap: () {
                        final reason = _selected;
                        if (reason == null) return;
                        final note = _noteCtrl.text.trim();
                        Navigator.of(context).pop(
                          QuitFeedbackResult(
                            leave: true,
                            reason: reason,
                            note: note.isEmpty ? null : note,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerBubbleRow extends StatelessWidget {
  const _TrainerBubbleRow({required this.trainer, required this.bubbleText});

  final Trainer trainer;
  final String bubbleText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 140,
          child: ClipRRect(
            child: Image.asset(
              trainer.avatarAsset,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 80,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChatBubble(text: bubbleText),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text});
  final String text;

  static const _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

class _ReasonChips extends StatelessWidget {
  const _ReasonChips({required this.selected, required this.onChanged});

  final QuitReason? selected;
  final ValueChanged<QuitReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final r in QuitReason.values)
          _Chip(
            label: r.displayLabel,
            selected: selected == r,
            onTap: () => onChanged(r),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF3B82F6)
                : Colors.white.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: selected ? 1.0 : 0.85),
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
    final len = widget.controller.text.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.controller,
            maxLines: 4,
            maxLength: widget.maxChars,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: "We'd love your feedback to improve!",
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$len/${widget.maxChars}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? (enabled
            ? const Color(0xFF2563EB)
            : Colors.white.withValues(alpha: 0.10))
        : Colors.white.withValues(alpha: 0.08);
    final fg = filled
        ? Colors.white
        : Colors.white.withValues(alpha: enabled ? 1.0 : 0.4);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

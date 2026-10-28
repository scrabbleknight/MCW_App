import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

/// Last question before the paywall: "How did you find us?". Mandatory —
/// CONTINUE stays disabled until an option is picked, and with "Other"
/// until something is typed. The ids match
/// `FunnelTracker.acquisitionSources`; the screen sends the pick (and the
/// "Other" text) to analytics so it can be compared with ViralEngine's
/// per-post attribution.
class HeardFromStep extends StatefulWidget {
  const HeardFromStep({
    super.key,
    required this.onCompleted,
    this.selected,
    this.otherText,
  });

  /// Earlier answer, so going back keeps it.
  final String? selected;
  final String? otherText;

  /// The picked id, and the trimmed text when it's `other` (else null).
  final void Function(String id, String? otherText) onCompleted;

  /// (id, label) in the order shown. The store follows the device.
  static List<(String, String)> get options => [
        ('tiktok', 'TikTok'),
        ('instagram', 'Instagram'),
        ('youtube', 'YouTube'),
        ('facebook', 'Facebook'),
        ('pinterest', 'Pinterest'),
        ('snapchat', 'Snapchat'),
        ('google', 'Google'),
        StorePlatform.isAndroid
            ? ('google_play', 'Google Play')
            : ('app_store', 'App Store'),
        ('friends', 'Friends or family'),
        ('other', 'Other'),
      ];

  @override
  State<HeardFromStep> createState() => _HeardFromStepState();
}

class _HeardFromStepState extends State<HeardFromStep> {
  late String? _picked = widget.selected;
  late final TextEditingController _other =
      TextEditingController(text: widget.otherText ?? '');

  /// Focus the box only right after "Other" is tapped, not on revisits.
  bool _focusOther = false;

  bool get _canContinue =>
      _picked != null &&
      (_picked != 'other' || _other.text.trim().isNotEmpty);

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _continue() {
    final id = _picked;
    if (id == null || !_canContinue) return;
    FocusScope.of(context).unfocus();
    widget.onCompleted(id, id == 'other' ? _other.text.trim() : null);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final options = HeardFromStep.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How did you find Military Calisthenics?',
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final (id, label) = options[i];
              final tile = OptionTile(
                key: ValueKey('heard_from_$id'),
                label: label,
                selected: _picked == id,
                onTap: () => setState(() {
                  if (id == 'other' && _picked != 'other') _focusOther = true;
                  _picked = id;
                }),
              );
              if (id != 'other' || _picked != 'other') return tile;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile,
                  const SizedBox(height: 10),
                  _OtherBox(
                    controller: _other,
                    autofocus: _focusOther,
                    onChanged: () => setState(() {}),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PrimaryCta(
          label: 'CONTINUE',
          onPressed: _continue,
          enabled: _canContinue,
        ),
      ],
    );
  }
}

class _OtherBox extends StatelessWidget {
  const _OtherBox({
    required this.controller,
    required this.autofocus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.hairline),
      ),
      child: TextField(
        key: const ValueKey('heard_from_other_text'),
        controller: controller,
        autofocus: autofocus,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        style: TextStyle(color: palette.chalk, fontSize: 15),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          counterText: '',
          hintText: 'Tell us where',
          hintStyle: TextStyle(color: palette.muted, fontSize: 15),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/onboarding_kit/onboarding_kit.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/auth/application/auth_service.dart';

/// Two-step phone login: enter number → enter SMS code. Returns the final
/// [LoginResult] via Navigator.pop when the flow is done or cancelled.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _sending = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter your phone number, including country code.');
      return;
    }
    final phone = raw.startsWith('+') ? raw : '+$raw';

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final challenge = await widget.authService.sendPhoneCode(phone);
      if (!mounted) return;
      if (challenge.wasAutoVerified && challenge.autoResult != null) {
        Navigator.of(context).pop(challenge.autoResult);
        return;
      }
      setState(() => _verificationId = challenge.verificationId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = "Couldn't send code — check the number and try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final verificationId = _verificationId;
    if (verificationId == null) return;
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code we sent.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    final result = await widget.authService.signInWithPhoneCode(
      verificationId: verificationId,
      smsCode: code,
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titleStyle = GoogleFonts.bigShouldersDisplay(
      fontWeight: FontWeight.w900,
      color: TacticalPalette.chalk,
      height: 0.9,
      letterSpacing: 1.3,
      fontSize: 44,
    );

    final askingForNumber = _verificationId == null;

    return Scaffold(
      backgroundColor: TacticalPalette.abyss,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: TacticalPalette.chalk,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                askingForNumber ? 'YOUR NUMBER' : 'ENTER CODE',
                style: titleStyle,
              ),
              const SizedBox(height: 10),
              Text(
                askingForNumber
                    ? 'We\'ll send you a one-time code by SMS.'
                    : 'Enter the 6-digit code we just sent to '
                        '${_phoneController.text.trim()}.',
                style: text.bodyMedium?.copyWith(color: TacticalPalette.mist),
              ),
              const SizedBox(height: 28),
              if (askingForNumber)
                _TacticalField(
                  controller: _phoneController,
                  hint: '+44 7700 900123',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                  ],
                )
              else
                _TacticalField(
                  controller: _codeController,
                  hint: '123456',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: TacticalPalette.danger),
                ),
              ],
              const Spacer(),
              PrimaryCta(
                label: askingForNumber
                    ? (_sending ? 'Sending…' : 'Send code')
                    : (_verifying ? 'Verifying…' : 'Verify'),
                onPressed: askingForNumber ? _sendCode : _verifyCode,
                enabled: !_sending && !_verifying,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TacticalField extends StatelessWidget {
  const _TacticalField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofocus: true,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: TacticalPalette.chalk,
            letterSpacing: 1.5,
          ),
      cursorColor: TacticalPalette.arctic,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: TacticalPalette.muted.withValues(alpha: 0.6)),
        filled: true,
        fillColor: TacticalPalette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TacticalPalette.hairline, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TacticalPalette.arctic, width: 1.6),
        ),
      ),
    );
  }
}

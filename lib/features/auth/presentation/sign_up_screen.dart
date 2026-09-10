import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/auth/application/auth_service.dart';
import 'package:military_calisthenics_women/features/auth/presentation/phone_login_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:provider/provider.dart';

/// Full-screen sign-up mirror of [LoginScreen].
///
/// Same three provider tiles, but each call runs in sign-up mode:
/// the existing-account guard rejects credentials that already belong to
/// a user (they're bounced back to log-in instead of creating a dup).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = AuthService();
  bool _busy = false;

  Future<void> _run(Future<LoginResult> Function() flow) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await flow();
      if (!mounted) return;
      _handleResult(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleResult(LoginResult result) async {
    switch (result.outcome) {
      case LoginOutcome.existingUser:
        // Fresh account created (or the credential is already logged in).
        // Mark onboarding complete and pop back to the app.
        await context.read<OnboardingController>().markCompleted();
        if (!mounted) return;
        Navigator.of(context).pop();
      case LoginOutcome.existingUserRejected:
        _snack(
          "That account already exists — tap Log in below to sign in instead.",
        );
      case LoginOutcome.newUserRejected:
        // Not expected on the sign-up screen, but handle defensively.
        _snack("Couldn't create an account — try logging in instead.");
      case LoginOutcome.cancelled:
        if (result.error != null) {
          _snack("Couldn't sign up: ${result.error}");
        }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: context.palette.chalk,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: context.palette.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
          closeIconColor: context.palette.chalk,
        ),
      );
  }

  Future<void> _openPhoneFlow() async {
    if (_busy) return;
    final result = await Navigator.of(context).push<LoginResult>(
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(authService: _auth, signUp: true),
      ),
    );
    if (result != null && mounted) _handleResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titleStyle = GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w900,
      color: context.palette.chalk,
      height: 0.9,
      letterSpacing: 1.4,
      fontSize: 38,
    );

    return Scaffold(
      backgroundColor: context.palette.abyss,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BackChevron(onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 24),
              Text('SIGN UP', style: titleStyle),
              const SizedBox(height: 12),
              Text(
                'Create your account in seconds.',
                style: text.bodyLarge?.copyWith(color: context.palette.mist),
              ),
              const SizedBox(height: 40),
              _ProviderTile(
                label: 'Sign up with Apple',
                icon: Icons.apple,
                onTap: () => _run(() => _auth.signInWithApple(signUp: true)),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              _ProviderTile(
                label: 'Sign up with Google',
                icon: Icons.g_mobiledata_rounded,
                onTap: () => _run(() => _auth.signInWithGoogle(signUp: true)),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              _ProviderTile(
                label: 'Sign up with Phone',
                icon: Icons.phone_iphone_rounded,
                onTap: _openPhoneFlow,
                enabled: !_busy,
              ),
              const Spacer(),
              if (_busy)
                Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: context.palette.arctic,
                    ),
                  ),
                ),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: text.bodyMedium?.copyWith(color: context.palette.muted),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Text(
                            'Log in',
                            style: text.bodyMedium?.copyWith(
                              color: context.palette.arcticSoft,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: context.palette.arcticSoft,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(
              Icons.chevron_left_rounded,
              color: context.palette.chalk,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: context.palette.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: context.palette.hairline, width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(icon, color: context.palette.chalk, size: 26),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.palette.chalk,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

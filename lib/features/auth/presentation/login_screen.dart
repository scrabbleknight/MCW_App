import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/auth/application/auth_service.dart';
import 'package:military_calisthenics_women/features/auth/presentation/phone_login_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:provider/provider.dart';

/// Full-screen log-in for users who already have an account.
///
/// Three provider tiles (Google, Apple, Phone); each is guarded by
/// [AuthService]'s `isNewUser` check so accidental sign-ups are rejected
/// and surfaced as "no account found — sign up instead" errors.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
        // Existing account: mirror the "onboarding done" flag locally so
        // the AppFlowGate routes them to Home on next rebuild.
        await context.read<OnboardingController>().markCompleted();
        if (!mounted) return;
        Navigator.of(context).pop();
      case LoginOutcome.newUserRejected:
        _snack(
          "No account found for that sign-in. Tap Start Now on the "
          "previous screen to create one.",
        );
      case LoginOutcome.cancelled:
        if (result.error != null) {
          _snack("Couldn't sign in: ${result.error}");
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
            style: const TextStyle(
              color: TacticalPalette.chalk,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: TacticalPalette.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
          closeIconColor: TacticalPalette.chalk,
        ),
      );
  }

  Future<void> _openPhoneFlow() async {
    if (_busy) return;
    final result = await Navigator.of(context).push<LoginResult>(
      MaterialPageRoute(builder: (_) => PhoneLoginScreen(authService: _auth)),
    );
    if (result != null && mounted) _handleResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titleStyle = GoogleFonts.bigShouldersDisplay(
      fontWeight: FontWeight.w900,
      color: TacticalPalette.chalk,
      height: 0.9,
      letterSpacing: 1.4,
      fontSize: 56,
    );

    return Scaffold(
      backgroundColor: TacticalPalette.abyss,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BackChevron(onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 24),
              Text('LOG IN', style: titleStyle),
              const SizedBox(height: 12),
              Text(
                'Continue with the account you already have.',
                style: text.bodyLarge?.copyWith(color: TacticalPalette.mist),
              ),
              const SizedBox(height: 40),
              _ProviderTile(
                label: 'Continue with Apple',
                icon: Icons.apple,
                onTap: () => _run(_auth.signInWithApple),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              _ProviderTile(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                onTap: () => _run(_auth.signInWithGoogle),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              _ProviderTile(
                label: 'Continue with Phone',
                icon: Icons.phone_iphone_rounded,
                onTap: _openPhoneFlow,
                enabled: !_busy,
              ),
              const Spacer(),
              if (_busy)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: TacticalPalette.arctic,
                    ),
                  ),
                ),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: text.bodyMedium?.copyWith(color: TacticalPalette.muted),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Text(
                            'Start Now',
                            style: text.bodyMedium?.copyWith(
                              color: TacticalPalette.arcticSoft,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: TacticalPalette.arcticSoft,
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
            child: const Icon(
              Icons.chevron_left_rounded,
              color: TacticalPalette.chalk,
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
        color: TacticalPalette.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: TacticalPalette.hairline, width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(icon, color: TacticalPalette.chalk, size: 26),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: TacticalPalette.chalk,
                        ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: TacticalPalette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

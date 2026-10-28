// GENERATED from ViralEngine/deepblue-kit/dart/deepblue_sign_in_sheet.dart — edit it there and run `npm run deepblue:sync`.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'deepblue_membership.dart';

/// "DeepBlue member? Sign in" — the one place an app lets an existing
/// DeepBlue All Access member unlock premium.
///
/// Store rules: this sheet never mentions a price, a website, or buying
/// anything, and links nowhere. It only signs an existing member in.
class DeepBlueSignInButton extends StatelessWidget {
  const DeepBlueSignInButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final m = DeepBlueMembership.instance;
    if (!m.enabled) return const SizedBox.shrink();
    return TextButton(
      onPressed: () => showDeepBlueSignIn(context),
      child: Text(
        'DeepBlue All Access member? Sign in',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Opens the sign-in sheet. Completes with whether premium is now unlocked.
Future<bool> showDeepBlueSignIn(BuildContext context) async {
  final m = DeepBlueMembership.instance;
  if (!m.enabled) return false;
  await m.init();
  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _DeepBlueSignInSheet(),
  );
  return m.hasAccess;
}

class _DeepBlueSignInSheet extends StatefulWidget {
  const _DeepBlueSignInSheet();

  @override
  State<_DeepBlueSignInSheet> createState() => _DeepBlueSignInSheetState();
}

class _DeepBlueSignInSheetState extends State<_DeepBlueSignInSheet> {
  static const _navy = Color(0xFF082F66);

  final _m = DeepBlueMembership.instance;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Future<void> Function(String code)? _confirm;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onChange);
  }

  @override
  void dispose() {
    _m.removeListener(_onChange);
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (_m.hasAccess) {
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('DeepBlue All Access is active. Premium unlocked.')),
      );
      return;
    }
    setState(() {});
  }

  Future<void> _go(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await work();
      if (mounted && _m.user != null && !_m.hasAccess) {
        _message = "This DeepBlue account doesn't have an active All Access membership.";
      }
    } catch (e) {
      _message = DeepBlueMembership.errorText(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _m.user;
    final isApple = defaultTargetPlatform == TargetPlatform.iOS;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DEEPBLUE ALL ACCESS',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            user == null ? 'Sign in with your DeepBlue account' : 'Signed in to DeepBlue',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            user == null
                ? 'Members unlock premium here with the same Google, Apple or phone sign-in they use for their DeepBlue account.'
                : (user.email ?? user.phoneNumber ?? ''),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (user == null) ...[
            if (isApple) _button('Continue with Apple', Icons.apple, () => _go(_m.signInWithApple)),
            _button('Continue with Google', Icons.g_mobiledata, () => _go(_m.signInWithGoogle)),
            if (!isApple) _button('Continue with Apple', Icons.apple, () => _go(_m.signInWithApple)),
            const SizedBox(height: 12),
            if (_confirm == null)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(labelText: 'Mobile number', hintText: '+44 7700 900123'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _sendCode,
                    style: FilledButton.styleFrom(backgroundColor: _navy),
                    child: const Text('Send code'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _go(() => _confirm!(_code.text.trim())),
                    style: FilledButton.styleFrom(backgroundColor: _navy),
                    child: const Text('Verify'),
                  ),
                ],
              ),
          ] else ...[
            OutlinedButton(
              onPressed: _busy ? null : () => _go(_m.refresh),
              child: const Text('Check again'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _go(_m.signOut),
              child: const Text('Use a different DeepBlue account'),
            ),
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator())),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }

  void _sendCode() {
    final phone = _phone.text.replaceAll(RegExp(r'\s+'), '');
    _go(() => _m.startPhoneSignIn(
          phone,
          onCodeSent: (confirm) => setState(() {
            _confirm = confirm;
            _message = "We've sent you a code by text message.";
          }),
          onError: (msg) => setState(() => _message = msg),
        ));
  }

  Widget _button(String label, IconData icon, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../utils/password_validation.dart';
import '../core/app_messenger.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.oobCode});
  final String oobCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _passwordsVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final pwd = _passwordController.text;
    final confirm = _confirmController.text;
    final err = PasswordValidation.errorText(pwd);
    if (err != null) {
      setState(() => _errorMessage = err);
      return;
    }
    if (pwd != confirm) {
      setState(() => _errorMessage = 'A két jelszó nem egyezik.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: pwd,
      );
      if (!mounted) return;
      AppMessenger.showSuccess('Jelszó sikeresen frissítve. Jelentkezz be.');
      context.go('/login');
    } on FirebaseAuthException catch (e) {
      final hu = {
        'expired-action-code': 'A visszaállítási link lejárt. Kérj újat.',
        'invalid-action-code': 'Érvénytelen visszaállítási link.',
        'user-disabled': 'A fiók le van tiltva.',
        'user-not-found': 'A felhasználó nem található.',
        'weak-password': 'A jelszó nem elég erős.',
      };
      setState(
          () => _errorMessage = hu[e.code] ?? 'Hiba történt: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'Ismeretlen hiba történt: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jelszó visszaállítása')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordsVisible,
                  decoration: InputDecoration(
                    labelText: 'Új jelszó',
                    border: const OutlineInputBorder(),
                    helperText:
                        'Min. 8 karakter, nagy+kisbetű, szám, speciális jel',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordsVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                          () => _passwordsVisible = !_passwordsVisible),
                    ),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: !_passwordsVisible,
                  decoration: const InputDecoration(
                    labelText: 'Új jelszó megerősítése',
                    border: OutlineInputBorder(),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFE74C3C)),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _reset,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Jelszó beállítása'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

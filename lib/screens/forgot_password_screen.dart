import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../core/app_messenger.dart';

/// Elfelejtett jelszó képernyő.
///
/// Megadott e-mail címre jelszó-visszaállító linket küld a Firebase Authentication
/// `sendPasswordResetEmail` hívással. Siker és hiba esetén SnackBar-on keresztül
/// ad visszajelzést.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Magyar Firebase Auth hibaüzenetek
  static const Map<String, String> _firebaseHu = {
    'user-not-found': 'Ez az e-mail cím nem található.',
    'invalid-email': 'Érvénytelen e-mail cím formátum.',
    'too-many-requests': 'Túl sok próbálkozás. Kérlek, próbáld meg később.',
  };

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppMessenger.showError('Kérlek, add meg az e-mail címed.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      AppMessenger.showSuccess('Jelszó-visszaállító e-mail elküldve.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/login');
      }
    } on FirebaseAuthException catch (e) {
      final msg = _firebaseHu[e.code] ?? 'Hiba történt: ${e.message}';
      AppMessenger.showError(msg);
    } catch (e) {
      AppMessenger.showError('Ismeretlen hiba történt: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elfelejtett jelszó'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Jelszó-visszaállító e-mail küldése'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

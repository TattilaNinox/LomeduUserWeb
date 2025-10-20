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
  String? _errorMessage;
  String? _successMessage;

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
      setState(() => _errorMessage = 'Kérlek, add meg az e-mail címed.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      // Jelszó visszaállító link a lomedu.hu domain-re mutat
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://lomedu.hu/#/reset-password',
          handleCodeInApp: true,
        ),
      );
      if (!mounted) return;
      _successMessage = 'Jelszó-visszaállító e-mail elküldve.';
      AppMessenger.showSuccess(_successMessage!);
    } on FirebaseAuthException catch (e) {
      final msg = _firebaseHu[e.code] ?? 'Hiba történt: ${e.message}';
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = 'Ismeretlen hiba történt: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Elfelejtett jelszó',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isMobile ? 32 : 48),
                ),
                child: Column(
                  children: [
                    SizedBox(height: isMobile ? 24 : 32),
                    // Nagy ikon
                    Container(
                      width: isMobile ? 100 : 120,
                      height: isMobile ? 100 : 120,
                      decoration: BoxDecoration(
                        color: const Color(0x1A1E3A8A),
                        borderRadius: BorderRadius.circular(isMobile ? 50 : 60),
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        size: 60,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: isMobile ? 24 : 32),
                    // Cím
                    Text(
                      'Jelszó visszaállítása',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    // Leírás
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Add meg az e-mail címed, és elküldjük a jelszó-visszaállító linket.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: isMobile ? 32 : 48),
                    // E-mail mező
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'E-mail cím',
                        prefixIcon: Icon(Icons.email_outlined,
                            color: Color(0xFF6B7280)),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF1E3A8A), width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    // Hiba/siker üzenetek
                    if (_errorMessage != null) ...[
                      SizedBox(height: isMobile ? 16 : 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Color(0xFFDC2626), fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_successMessage != null) ...[
                      SizedBox(height: isMobile ? 16 : 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Color(0xFF16A34A), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                    color: Color(0xFF16A34A), fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: isMobile ? 24 : 32),
                    // Küldés gomb
                    SizedBox(
                      width: double.infinity,
                      height: isMobile ? 48 : 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(isMobile ? 24 : 28),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Jelszó-visszaállító e-mail küldése',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 24),
                    // Vissza a bejelentkezéshez
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'Vissza a bejelentkezéshez',
                        style: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

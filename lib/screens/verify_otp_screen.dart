import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:go_router/go_router.dart';

import '../core/two_factor_auth.dart';

/// Kétfaktoros hitelesítési kód ellenőrzésére szolgáló képernyő.
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  VerifyOtpScreenState createState() => VerifyOtpScreenState();
}

class VerifyOtpScreenState extends State<VerifyOtpScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  /// Ellenőrzi, hogy a felhasználó jogosult-e ezt a képernyőt látni
  Future<void> _checkUserStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  /// TOTP kód ellenőrzése és bejelentkezés befejezése
  Future<void> _verifyOtp(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Nem vagy bejelentkezve. Kérjük jelentkezz be újra.';
          _isLoading = false;
        });
        return;
      }

      final isValid = await TwoFactorAuth.validateLogin(user, code);

      if (isValid) {
        if (mounted) {
          // Sikeres bejelentkezés, átirányítás a főoldalra
          context.go('/notes');
        }
      } else {
        setState(() {
          _errorMessage = 'Érvénytelen kód. Próbáld újra!';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hiba történt: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Kijelentkezés, ha valami probléma van
  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kétfaktoros hitelesítés',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.security,
                color: Color(0xFF1E3A8A),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Add meg a Google Authenticator alkalmazás által generált 6 jegyű kódot:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final defaultPinTheme = PinTheme(
                    width: 44,
                    height: 48,
                    textStyle: const TextStyle(fontSize: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                    ),
                  );
                  return Pinput(
                    length: 6,
                    controller: _otpController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(
                            color: const Color(0xFF1E3A8A), width: 2),
                      ),
                    ),
                    onCompleted: _verifyOtp,
                    onSubmitted: _verifyOtp,
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          // A kód beírása után az onSubmit hívódik meg
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Ellenőrzés',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut,
                child: const Text('Vissza a bejelentkezéshez'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

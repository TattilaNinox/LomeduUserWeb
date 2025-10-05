import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final regExp = RegExp(
        r"^(?:[a-zA-Z0-9_'^&/+-])+(?:\\.(?:[a-zA-Z0-9_'^&/+-])+)*@(?:(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,})$");
    return regExp.hasMatch(email);
  }

  String _deviceFingerprint() {
    if (kIsWeb) {
      // Egyszerű web fingerprint – nem írja felül később
      return 'flutter_web_${DateTime.now().millisecondsSinceEpoch % 100000}';
    }
    return 'flutter_device_unknown';
  }

  Future<void> _register() async {
    if (_lastNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Vezetéknév kötelező.');
      return;
    }
    if (_firstNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Keresztnév kötelező.');
      return;
    }
    if (!_isValidEmail(_emailController.text.trim())) {
      setState(
          () => _errorMessage = 'Kérjük, adjon meg egy érvényes email címet.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'A két jelszó nem egyezik.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create user in Firebase Authentication
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Kötelező/kezdeti mezők létrehozása/pótlása
      final now = DateTime.now();
      final trialEnd = now.add(const Duration(days: 5));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': _emailController.text.trim(),
        'userType': 'normal',
        'science': 'Alap',
        'subscriptionStatus': 'free',
        'isSubscriptionActive': false,
        'subscriptionEndDate': null,
        'lastPaymentDate': null,
        'freeTrialStartDate': Timestamp.fromDate(now),
        'freeTrialEndDate': Timestamp.fromDate(trialEnd),
        'deviceRegistrationDate': Timestamp.fromDate(now),
        'authorizedDeviceFingerprint': _deviceFingerprint(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
      }, SetOptions(merge: true));

      // E-mail megerősítő levél küldése
      await userCredential.user!.sendEmailVerification();

      if (mounted) {
        context.go('/verify-email');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Hiba történt a regisztráció során: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
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
                      'Regisztráció',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Vezetéknév',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon:
                            const Icon(Icons.person, color: Color(0xFF6B7280)),
                      ),
                      autofillHints: const [AutofillHints.familyName],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'Keresztnév',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Color(0xFF6B7280)),
                      ),
                      autofillHints: const [AutofillHints.givenName],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon:
                            const Icon(Icons.email, color: Color(0xFF6B7280)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Jelszó',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon:
                            const Icon(Icons.lock, color: Color(0xFF6B7280)),
                      ),
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Jelszó megerősítése',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF6B7280)),
                      ),
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE74C3C),
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Regisztráció',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Már van fiókod? Bejelentkezés'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

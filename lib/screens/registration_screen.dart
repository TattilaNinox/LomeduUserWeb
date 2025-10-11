import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/device_fingerprint.dart';

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
  bool _passwordsVisible = false;
  String? _errorMessage;
  bool _isLoading = false;

  /// Külön segédfüggvény az email megerősítő levél küldésére (weben ActionCodeSettings-szel).
  Future<void> _sendVerificationEmail(User user) async {
    try {
      if (kIsWeb) {
        final origin = Uri.base
            .origin; // pl. https://lomedu-user-web.web.app vagy http://localhost:xxxx
        await user.sendEmailVerification(ActionCodeSettings(
          url: '$origin/#/login?from=verify',
          handleCodeInApp: true,
        ));
      } else {
        await user.sendEmailVerification();
      }
    } on TypeError catch (e) {
      debugPrint("MFA TypeError elkapva (nem kritikus): $e");
    } catch (e) {
      debugPrint("Hiba a megerősítő email küldésekor: $e");
    }
  }

  bool _isValidEmail(String email) {
    // Javított regex: raw string + helyes egy backslash-es escape a regexben
    final regExp = RegExp(
        r"^(?:[a-zA-Z0-9_'^&/+-])+(?:\.(?:[a-zA-Z0-9_'^&/+-])+)*@(?:(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})$");
    return regExp.hasMatch(email);
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
      debugPrint("1. Regisztráció megkezdése...");
      // 1. Auth fiók létrehozása
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user!;
      debugPrint(
          "2. Firebase Auth felhasználó sikeresen létrehozva: ${user.uid}");

      // 2. Verifikációs email küldése AZONNAL
      try {
        await _sendVerificationEmail(user);
        debugPrint("3. Email megerősítő függvény lefutott.");
      } catch (e) {
        debugPrint("3. Email megerősítő hiba (de folytatjuk): $e");
        // Folytatjuk a regisztrációt, még ha az email küldés hibás is
      }

      // 3. Próbaidőszak kiszámítása (most + 5 nap)
      final now = DateTime.now();
      final trialEnd = now.add(const Duration(days: 5));
      debugPrint("4. Próbaidőszak adatai kiszámítva.");

      // 4. Firestore adatok összeállítása a specifikáció szerint
      // Először töröljük a korábbi ujjlenyomatot, hogy új stabilat generáljon
      await DeviceFingerprint.clearWebFingerprint();
      final deviceFingerprint = await DeviceFingerprint.getCurrentFingerprint();
      debugPrint('=== REGISTRATION DEBUG ===');
      debugPrint('Generated Device Fingerprint: $deviceFingerprint');

      final newUserDoc = {
        'email': user.email,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'userType': 'normal',
        'science': 'Egészségügyi kártevőírtó',
        'subscriptionStatus': 'free',
        'isSubscriptionActive': false,
        'subscriptionEndDate': null,
        'lastPaymentDate': null,
        'freeTrialStartDate': Timestamp.fromDate(now),
        'freeTrialEndDate': Timestamp.fromDate(trialEnd),
        'deviceRegistrationDate': Timestamp.fromDate(now),
        'authorizedDeviceFingerprint': deviceFingerprint,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      debugPrint("5. Firestore dokumentum összeállítva.");

      // 5. Firestore írás (merge: true opcióval)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(newUserDoc, SetOptions(merge: true));
      debugPrint("6. Firestore dokumentum sikeresen elmentve.");

      // 6. UI: irányítás a "Ellenőrizd az emailed!" képernyőre
      if (mounted) {
        debugPrint("7. Átirányítás a /verify-email oldalra...");
        // Kis késleltetés, hogy a DeviceChecker ne zavarjon
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            try {
              context.go('/verify-email');
              debugPrint("8. Sikeres átirányítás a /verify-email oldalra");
            } catch (e) {
              debugPrint("8. Átirányítási hiba: $e");
              // Fallback: próbáljuk meg újra
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) {
                  try {
                    context.go('/verify-email');
                    debugPrint("9. Második átirányítási kísérlet sikeres");
                  } catch (e2) {
                    debugPrint(
                        "9. Második átirányítási kísérlet is hibás: $e2");
                  }
                }
              });
            }
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("!!! HIBA (FirebaseAuthException): ${e.code} - ${e.message}");
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint("!!! HIBA (Általános Exception): $e");
      setState(() {
        _errorMessage = 'Hiba történt a regisztráció során: $e';
      });
    } finally {
      debugPrint("8. Finally blokk lefutott.");
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
                      obscureText: !_passwordsVisible,
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
                      obscureText: !_passwordsVisible,
                      decoration: InputDecoration(
                        labelText: 'Jelszó megerősítése',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF6B7280)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordsVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordsVisible = !_passwordsVisible;
                            });
                          },
                        ),
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

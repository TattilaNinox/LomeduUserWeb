import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:cloud_functions/cloud_functions.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  int _cooldown = 0;
  bool _verifying = false;
  String? _error;

  /// Firebase hibákat átfordítja felhasználóbarát magyar üzenetekre
  String _getUserFriendlyError(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('expired-action-code') || errorLower.contains('lejárt')) {
      return 'A megerősítő link lejárt. Kérjük, kattints az "Újraküldés" gombra új link megkéréséhez.';
    }
    if (errorLower.contains('invalid-action-code') || errorLower.contains('invalid')) {
      return 'Érvénytelen vagy már felhasznált megerősítő link.';
    }
    if (errorLower.contains('user-disabled')) {
      return 'A felhasználói fiók le van tiltva.';
    }
    if (errorLower.contains('user-not-found')) {
      return 'A felhasználó nem található. Kérjük, regisztrálj újra.';
    }
    if (errorLower.contains('too-many-requests')) {
      return 'Túl sok próbálkozás. Kérjük, próbáld újra később.';
    }
    if (errorLower.contains('network')) {
      return 'Hálózati hiba. Ellenőrizd az internetkapcsolatodat és próbáld újra.';
    }
    if (errorLower.contains('email') && errorLower.contains('error')) {
      return 'Hiba az email küldésekor. Kérjük, próbáld újra később.';
    }
    
    return 'Hiba történt. Kérjük, próbáld újra később.';
  }

  void _listenForVerificationFromOtherTab() {
    if (!kIsWeb) return;
    try {
      // BroadcastChannel figyelése JS-ből
      // ignore: avoid_dynamic_calls
      final channel =
          js.context.callMethod('BroadcastChannel', ['lomedu-auth']);
      channel.callMethod('addEventListener', [
        'message',
        (dynamic event) {
          try {
            final data = event?.data?.toString();
            if (data == 'email-verified' && mounted) {
              context.go('/login');
            }
          } catch (_) {}
        }
      ]);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _applyVerifyCodeIfPresent();
    _listenForVerificationFromOtherTab();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;

      try {
        await u.reload();
        final reloadedUser = FirebaseAuth.instance.currentUser;
        if (reloadedUser != null && reloadedUser.emailVerified && mounted) {
          // Biztonsági lépés: jelentkezzünk ki, és menjünk a login képernyőre
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
          if (mounted) context.go('/login');
        }
      } on TypeError catch (e) {
        debugPrint("MFA TypeError during reload (nem kritikus): $e");
      } catch (e) {
        debugPrint("User reload hiba: $e");
      }
    });
  }

  Future<void> _applyVerifyCodeIfPresent() async {
    if (!kIsWeb) return;
    final qp = Uri.base.queryParameters;
    final mode = qp['mode'];
    final code = qp['oobCode'];
    if (mode == 'verifyEmail' && code != null && code.isNotEmpty) {
      setState(() {
        _verifying = true;
        _error = null;
      });
      try {
        await FirebaseAuth.instance.applyActionCode(code);
        try {
          await FirebaseAuth.instance.currentUser?.reload();
        } catch (_) {}
        if (!mounted) return;
        // Jelzés a login képernyő felé, majd átirányítás
        try {
          // ignore: avoid_dynamic_calls
          final channel =
              js.context['BroadcastChannel'].callMethod('new', ['lomedu-auth']);
          channel.callMethod('postMessage', ['email-verified']);
        } catch (_) {}
        _navigateToLoginAfterVerify();
      } on FirebaseAuthException catch (e) {
        setState(() {
          _error = _getUserFriendlyError(e.code);
        });
      } catch (e) {
        setState(() {
          _error = 'Ismeretlen hiba történt: $e';
        });
      } finally {
        if (mounted) setState(() => _verifying = false);
      }
    }
  }

  void _navigateToLoginAfterVerify() {
    if (!mounted) return;
    if (kIsWeb) {
      try {
        final history = js.context['history'];
        const origin = 'https://www.lomedu.hu';
        history.callMethod(
            'replaceState', [null, '', '$origin/#/login?from=verify']);
      } catch (_) {}
    }
    context.go('/login?from=verify');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    try {
      debugPrint("Email újraküldés indítása...");

      try {
        await FirebaseFunctions.instance.httpsCallable('initiateVerification').call({'userId': u.uid});
        debugPrint("Email sikeresen újraküldve!");
      } catch (e) {
        debugPrint("Email resend hiba: $e");
        setState(() {
          _error = _getUserFriendlyError(e.toString());
        });
      }
      debugPrint("Email sikeresen újraküldve!");
      setState(() => _cooldown = 30);
      _tickCooldown();
    } on TypeError catch (e) {
      debugPrint("MFA TypeError during resend (nem kritikus): $e");
      // Folytatjuk a cooldown-t, mintha sikeres lett volna
      setState(() => _cooldown = 30);
      _tickCooldown();
    } catch (e) {
      debugPrint("Email resend hiba: $e");
      setState(() {
        _error = _getUserFriendlyError(e.toString());
      });
    }
  }

  void _tickCooldown() {
    if (_cooldown <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _cooldown -= 1);
      if (_cooldown > 0) _tickCooldown();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'E-mail megerősítés',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_verifying) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 4),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0x1A1E3A8A),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Color(0xFF1E3A8A),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ellenőrizd az e-mailjeidet!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elküldtük a megerősítő levelet. A megerősítés után ez az ablak bezáródik, és a bejelentkezés képernyőre jutsz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Hasznos tippek
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E6),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFFFB74D), width: 1),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 Tippek:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• Ellenőrizd a levélszemét mappát\n'
                          '• Várj 1-2 percet az email megérkezésére\n'
                          '• Gmail-nél a "További" tab-ban nézz\n'
                          '• Ha nem érkezik, kattints az "Újraküldés" gombra',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE65100),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Jelenlegi email információ
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFD0D8E0), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Megerősítéshez szükséges email:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          FirebaseAuth.instance.currentUser?.email ??
                              'Ismeretlen',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hiba:',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _cooldown > 0 ? null : _resend,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(
                        _cooldown > 0
                            ? 'Újraküldés $_cooldown s'
                            : 'Megerősítő e-mail újraküldése',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Vissza a bejelentkezéshez'),
                  ),
                  const SizedBox(height: 4),
                  // Szándékos: manuális bezáró gomb helyett automatikus redirect működik
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

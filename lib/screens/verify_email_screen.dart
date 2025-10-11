import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  int _cooldown = 0;

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
      await u.sendEmailVerification();
      setState(() => _cooldown = 30);
      _tickCooldown();
    } on TypeError catch (e) {
      debugPrint("MFA TypeError during resend (nem kritikus): $e");
      // Folytatjuk a cooldown-t, mintha sikeres lett volna
      setState(() => _cooldown = 30);
      _tickCooldown();
    } catch (e) {
      debugPrint("Email resend hiba: $e");
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

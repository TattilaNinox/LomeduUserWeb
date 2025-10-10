import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;

      try {
        await u.reload();
        final reloadedUser = FirebaseAuth.instance.currentUser;
        if (reloadedUser != null && reloadedUser.emailVerified && mounted) {
          context.go('/notes');
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
      appBar: AppBar(title: const Text('E-mail megerősítés')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Kérjük, erősítse meg az e-mail címét. Az állapot 5 mp-enként frissül.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cooldown > 0 ? null : _resend,
              child: Text(_cooldown > 0
                  ? 'Újraküldés $_cooldown s'
                  : 'Megerősítő e-mail újraküldése'),
            ),
          ],
        ),
      ),
    );
  }
}

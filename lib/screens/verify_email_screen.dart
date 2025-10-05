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
      await u.reload();
      if (u.emailVerified && mounted) {
        context.go('/notes');
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
    await u.sendEmailVerification();
    setState(() => _cooldown = 30);
    _tickCooldown();
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

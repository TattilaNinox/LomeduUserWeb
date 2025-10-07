import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../utils/device_fingerprint.dart';

/// A DeviceChecker widget globálisan figyeli a felhasználó eszközének ujjlenyomatát
/// és kijelentkezteti a felhasználót, ha az nem egyezik a Firestore-ban tárolttal.
/// 
/// Ez a widget csak akkor fut, ha a felhasználó be van jelentkezve és nem
/// auth-related képernyőkön van (login, register, device-change, verify-email).
class DeviceChecker extends StatefulWidget {
  /// A gyerek widget, amit a DeviceChecker becsomagol
  final Widget child;

  const DeviceChecker({super.key, required this.child});

  @override
  State<DeviceChecker> createState() => _DeviceCheckerState();
}

class _DeviceCheckerState extends State<DeviceChecker> {
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  String? _currentFingerprint;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDeviceCheck();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }

  /// Inicializálja az eszköz ellenőrzést
  Future<void> _initializeDeviceCheck() async {
    try {
      // Jelenlegi felhasználó lekérése
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isInitialized = true);
        return;
      }

      // Jelenlegi eszköz ujjlenyomatának lekérése
      _currentFingerprint = await DeviceFingerprint.getCurrentFingerprint();
      
      print('DeviceChecker: Checking device for user ${user.uid}, fingerprint: $_currentFingerprint');

      // Firestore listener beállítása a felhasználó dokumentumára
      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(_onUserDocumentChanged);

      setState(() => _isInitialized = true);
    } catch (error) {
      print('DeviceChecker: Error initializing device check: $error');
      setState(() => _isInitialized = true);
    }
  }

  /// Firestore dokumentum változásának kezelése
  void _onUserDocumentChanged(DocumentSnapshot snapshot) {
    if (!mounted) return;

    try {
      if (!snapshot.exists) {
        print('DeviceChecker: User document not found');
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      final authorizedFingerprint = data?['authorizedDeviceFingerprint'] as String?;
      
      print('DeviceChecker: Current fingerprint: $_currentFingerprint, Allowed: $authorizedFingerprint');

      // Ha van engedélyezett ujjlenyomat és az nem egyezik a jelenlegivel
      if (authorizedFingerprint != null && 
          authorizedFingerprint.isNotEmpty && 
          _currentFingerprint != null &&
          authorizedFingerprint != _currentFingerprint) {
        
        print('DeviceChecker: Device fingerprint mismatch! Logging out user...');
        _logoutUser();
      }
    } catch (error) {
      print('DeviceChecker: Error checking device: $error');
    }
  }

  /// Felhasználó kijelentkeztetése
  Future<void> _logoutUser() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Navigálás a bejelentkezési oldalra
        context.go('/login');
      }
    } catch (error) {
      print('DeviceChecker: Error during logout: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ha még nincs inicializálva, csak a gyerek widget-et jelenítsd meg
    if (!_isInitialized) {
      return widget.child;
    }

    // Ellenőrizzük, hogy auth-related képernyőn vagyunk-e
    final currentLocation = GoRouterState.of(context).uri.path;
    final isAuthScreen = currentLocation.startsWith('/login') ||
                        currentLocation.startsWith('/register') ||
                        currentLocation.startsWith('/device-change') ||
                        currentLocation.startsWith('/verify-email');

    // Ha auth képernyőn vagyunk, ne futtassuk az ellenőrzést
    if (isAuthScreen) {
      return widget.child;
    }

    // Ellenőrizzük, hogy be van-e jelentkezve a felhasználó
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return widget.child;
    }

    // Ha minden rendben, jelenítsd meg a gyerek widget-et
    return widget.child;
  }
}


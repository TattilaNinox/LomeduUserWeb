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

class _DeviceCheckerState extends State<DeviceChecker> with WidgetsBindingObserver {
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  Timer? _periodicCheckTimer;
  String? _currentFingerprint;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDeviceCheck();
    
    // Figyeljük a Firebase Auth állapot változásait
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _initializeDeviceCheck();
      } else {
        _cleanup();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userDocSubscription?.cancel();
    _authStateSubscription?.cancel();
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Amikor az app visszatér a foreground-ba, ellenőrizzük újra
      _initializeDeviceCheck();
    }
  }

  /// Inicializálja az eszköz ellenőrzést
  Future<void> _initializeDeviceCheck() async {
    try {
      // Először töröljük a régi subscription-t
      _cleanup();
      
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

      // Periódikus ellenőrzés is (5 másodpercenként)
      _periodicCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        _checkDevicePeriodically();
      });

      setState(() => _isInitialized = true);
    } catch (error) {
      print('DeviceChecker: Error initializing device check: $error');
      setState(() => _isInitialized = true);
    }
  }

  /// Törli a subscription-öket
  void _cleanup() {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
  }

  /// Periódikus eszköz ellenőrzés
  Future<void> _checkDevicePeriodically() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>?;
      final authorizedFingerprint = data?['authorizedDeviceFingerprint'] as String?;
      
      print('DeviceChecker: Periodic check - Current: $_currentFingerprint, Allowed: $authorizedFingerprint');

      if (authorizedFingerprint != null && 
          authorizedFingerprint.isNotEmpty && 
          _currentFingerprint != null &&
          authorizedFingerprint != _currentFingerprint) {
        
        print('DeviceChecker: Periodic check - Device mismatch! Logging out user...');
        _logoutUser();
      }
    } catch (error) {
      print('DeviceChecker: Error in periodic check: $error');
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


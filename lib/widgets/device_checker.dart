import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../utils/device_fingerprint.dart';
import 'package:web/web.dart' as web;

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

class _DeviceCheckerState extends State<DeviceChecker>
    with WidgetsBindingObserver {
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  Timer? _periodicCheckTimer;
  String? _currentFingerprint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDeviceCheck();

    // Figyeljük a Firebase Auth állapot változásait
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;

      if (user == null) {
        // Kijelentkezett: mindent leállítunk, a központi router majd a /login-re visz.
        _cleanup();
      } else if (!user.emailVerified) {
        // Nincs még email-verifikálva → átirányítjuk a verify képernyőre, de
        // várunk, amíg a GoRouter biztosan elérhető lesz.
        _cleanup();
        // Várunk, amíg a GoRouter biztosan elérhető lesz
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          try {
            context.go('/verify-email');
            debugPrint('DeviceChecker: Successfully navigated to verify-email');
          } catch (e) {
            debugPrint('DeviceChecker: Navigation failed: $e');
            // Ha még mindig nem megy, várunk még
            Future.delayed(const Duration(milliseconds: 2000), () {
              if (mounted) {
                try {
                  context.go('/verify-email');
                  debugPrint(
                      'DeviceChecker: Second navigation attempt successful');
                } catch (e2) {
                  debugPrint(
                      'DeviceChecker: Second navigation attempt failed: $e2');
                }
              }
            });
          }
        });
      } else {
        // Ha van felhasználó ÉS meg is erősítette az emailjét,
        // akkor elindítjuk a biztonsági ellenőrzést.
        _initializeDeviceCheck();
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

      // Várunk egy kicsit, hogy a Firebase inicializálódjon
      await Future.delayed(const Duration(milliseconds: 500));

      // Jelenlegi felhasználó lekérése
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      // Jelenlegi eszköz ujjlenyomatának lekérése
      _currentFingerprint = await DeviceFingerprint.getCurrentFingerprint();

      debugPrint(
          'DeviceChecker: Checking device for user ${user.uid}, fingerprint: $_currentFingerprint');

      // Firestore listener beállítása a felhasználó dokumentumára
      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(_onUserDocumentChanged);

      // Periódikus ellenőrzés is (5 másodpercenként)
      _periodicCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _checkDevicePeriodically();
      });
    } on TypeError catch (e) {
      debugPrint(
          'DeviceChecker: MFA TypeError during initialization (nem kritikus): $e');
    } catch (error) {
      debugPrint('DeviceChecker: Error initializing device check: $error');
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

      final data = userDoc.data();

      // Admin ellenőrzés
      final userType = data?['userType'] as String? ?? '';
      final isAdmin = userType.toLowerCase() == 'admin';

      if (isAdmin) {
        debugPrint('DeviceChecker: Periodic check - User is admin, skipping');
        return;
      }

      final authorizedFingerprint =
          data?['authorizedDeviceFingerprint'] as String?;

      debugPrint(
          'DeviceChecker: Periodic check - Current: $_currentFingerprint, Allowed: $authorizedFingerprint');

      if (authorizedFingerprint != null &&
          authorizedFingerprint.isNotEmpty &&
          _currentFingerprint != null &&
          authorizedFingerprint != _currentFingerprint) {
        debugPrint(
            'DeviceChecker: Periodic check - Device mismatch! Logging out user...');
        _logoutUser();
      }
    } catch (error) {
      debugPrint('DeviceChecker: Error in periodic check: $error');
    }
  }

  /// Firestore dokumentum változásának kezelése
  void _onUserDocumentChanged(DocumentSnapshot snapshot) {
    if (!mounted) return;

    try {
      if (!snapshot.exists) {
        debugPrint('DeviceChecker: User document not found');
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;

      // Admin ellenőrzés - ha admin, kihagyjuk az eszköz ellenőrzést
      final userType = data?['userType'] as String? ?? '';
      final isAdmin = userType.toLowerCase() == 'admin';

      if (isAdmin) {
        debugPrint('DeviceChecker: User is admin, skipping device check');
        return; // Admin felhasználóknál ne ellenőrizzük az eszközt
      }

      final authorizedFingerprint =
          data?['authorizedDeviceFingerprint'] as String?;

      // Ha van deviceChangeDate, akkor frissítsük a current fingerprint-et
      final deviceChangeDate = data?['deviceChangeDate'];
      if (deviceChangeDate != null) {
        debugPrint(
            'DeviceChecker: Device change detected, refreshing current fingerprint');
        _refreshCurrentFingerprint();
      }

      debugPrint(
          'DeviceChecker: Current fingerprint: $_currentFingerprint, Allowed: $authorizedFingerprint');

      // Ha van engedélyezett ujjlenyomat és az nem egyezik a jelenlegivel
      if (authorizedFingerprint != null &&
          authorizedFingerprint.isNotEmpty &&
          _currentFingerprint != null &&
          authorizedFingerprint != _currentFingerprint) {
        debugPrint(
            'DeviceChecker: Device fingerprint mismatch! Logging out user...');
        _logoutUser();
      }
    } catch (error) {
      debugPrint('DeviceChecker: Error checking device: $error');
    }
  }

  /// Frissíti a jelenlegi eszköz ujjlenyomatát
  Future<void> _refreshCurrentFingerprint() async {
    try {
      _currentFingerprint = await DeviceFingerprint.getCurrentFingerprint();
      debugPrint(
          'DeviceChecker: Refreshed current fingerprint: $_currentFingerprint');
    } catch (error) {
      debugPrint('DeviceChecker: Error refreshing fingerprint: $error');
    }
  }

  /// Felhasználó kijelentkeztetése
  Future<void> _logoutUser() async {
    try {
      debugPrint('DeviceChecker: ===== LOGOUT STARTED =====');
      debugPrint('DeviceChecker: Logging out user due to device mismatch');

      // Kijelentkeztetjük a felhasználót
      await FirebaseAuth.instance.signOut();
      debugPrint('DeviceChecker: User signed out from Firebase');

      // Navigálás a login oldalra - egyszerűbb megközelítés
      if (mounted) {
        try {
          // Próbáljuk meg a GoRouter.of(context) használatával
          final router = GoRouter.of(context);
          router.go('/login');
          debugPrint('DeviceChecker: Successfully navigated using GoRouter.of');
        } catch (routerError) {
          debugPrint('DeviceChecker: GoRouter.of failed: $routerError');

          // Fallback: próbáljuk meg a context.go-val
          try {
            context.go('/login');
            debugPrint(
                'DeviceChecker: Successfully navigated using context.go');
          } catch (contextError) {
            debugPrint('DeviceChecker: context.go also failed: $contextError');

            // Utolsó fallback: web navigáció
            try {
              // Web-specifikus navigáció
              if (kIsWeb) {
                web.window.location.href = '/login';
                debugPrint(
                    'DeviceChecker: Successfully navigated using window.location');
              }
            } catch (webError) {
              debugPrint(
                  'DeviceChecker: Web navigation also failed: $webError');
            }
          }
        }
      } else {
        debugPrint('DeviceChecker: Widget is not mounted, cannot navigate');
      }

      debugPrint('DeviceChecker: ===== LOGOUT COMPLETED =====');
    } catch (error) {
      debugPrint('DeviceChecker: Error during logout: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mindig jelenítsd meg a gyerek widget-et, a DeviceChecker csak háttérben fut
    return widget.child;
  }

  /// Tesztelési metódus - manuálisan kijelentkeztet
  void testLogout() {
    debugPrint('DeviceChecker: Manual test logout triggered');
    _logoutUser();
  }
}

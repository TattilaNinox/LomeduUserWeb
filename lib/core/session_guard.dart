import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/device_fingerprint.dart';

/// A bejelentkezési és eszköz-hozzáférési állapot központi őre.
///
/// Nem navigál és nem jelentkeztet ki — csak állapotot szolgáltat a routernek.
class SessionGuard extends ChangeNotifier {
  SessionGuard._internal();

  static final SessionGuard instance = SessionGuard._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userDocSubscription;

  AuthStatus _authStatus = AuthStatus.loggedOut;
  DeviceAccess _deviceAccess = DeviceAccess.loading;
  String? _currentFingerprint;
  bool _initialized = false;

  AuthStatus get authStatus => _authStatus;
  DeviceAccess get deviceAccess => _deviceAccess;

  /// Egyszeri inicializálás — feliratkozás az auth és user doc változásokra.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    _authSubscription = _auth.authStateChanges().listen((user) async {
      // Alapértelmezett állapotok
      if (user == null) {
        _authStatus = AuthStatus.loggedOut;
        _deviceAccess = DeviceAccess.loading;
        await _cancelUserDocSubscription();
        notifyListeners();
        return;
      }

      if (!user.emailVerified) {
        _authStatus = AuthStatus.emailUnverified;
        _deviceAccess = DeviceAccess.loading;
        await _cancelUserDocSubscription();
        notifyListeners();
        return;
      }

      // Be van jelentkezve és email verifikált
      _authStatus = AuthStatus.loggedIn;
      _deviceAccess = DeviceAccess.loading;
      notifyListeners();

      try {
        // Aktuális fingerprint előkészítése (cache-elve is elég)
        _currentFingerprint = await DeviceFingerprint.getCurrentFingerprint();

        // Felhasználói dokumentum figyelése
        await _cancelUserDocSubscription();
        _userDocSubscription = _firestore
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen(_onUserDocChanged, onError: (error, _) {
          // Hiba esetén ne rúgjuk ki a felhasználót, csak jelezzük, hogy loading
          _deviceAccess = DeviceAccess.loading;
          notifyListeners();
        });
      } catch (_) {
        _deviceAccess = DeviceAccess.loading;
        notifyListeners();
      }
    });
  }

  Future<void> _cancelUserDocSubscription() async {
    await _userDocSubscription?.cancel();
    _userDocSubscription = null;
  }

  void _onUserDocChanged(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      _deviceAccess = DeviceAccess.loading;
      notifyListeners();
      return;
    }

    // Admin esetén ne korlátozzuk az eszközt
    final userType = (data['userType'] as String? ?? '').toLowerCase();
    final isAdmin = userType == 'admin';
    if (isAdmin) {
      _deviceAccess = DeviceAccess.allowed;
      notifyListeners();
      return;
    }

    final String? allowedFingerprint =
        data['authorizedDeviceFingerprint'] as String?;

    // Ha nincs regisztrált fingerprint, tekintsük engedélyezettnek (első eszköz regisztráció kezelhető külön folyamatban)
    if (allowedFingerprint == null || allowedFingerprint.isEmpty) {
      _deviceAccess = DeviceAccess.allowed;
      notifyListeners();
      return;
    }

    if (_currentFingerprint == null) {
      _deviceAccess = DeviceAccess.loading;
      notifyListeners();
      return;
    }

    _deviceAccess = (allowedFingerprint == _currentFingerprint)
        ? DeviceAccess.allowed
        : DeviceAccess.denied;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}

enum AuthStatus { loggedOut, emailUnverified, loggedIn }

enum DeviceAccess { loading, allowed, denied }

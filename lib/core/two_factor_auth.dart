import 'dart:math';
import 'dart:typed_data';
import 'package:base32/base32.dart';
import 'package:otp/otp.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Kétfaktoros hitelesítést kezelő osztály
class TwoFactorAuth {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_2fa';

  /// Titkos kulcs generálása a felhasználó számára
  static String generateSecret() {
    final Random random = Random.secure();
    final Uint8List randomBytes =
        Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
    return base32.encode(randomBytes);
  }

  /// TOTP kód generálása a titkos kulcs alapján (ellenőrzéshez)
  static String generateTOTP(String secret) {
    return OTP.generateTOTPCodeString(
      secret,
      DateTime.now().millisecondsSinceEpoch,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  /// TOTP kód ellenőrzése
  static bool verifyTOTP(String secret, String code) {
    final currentCode = generateTOTP(secret);
    return currentCode == code;
  }

  /// Google Authenticator URI generálása QR kód számára
  static String getGoogleAuthenticatorUri(String secret, String email,
      {String issuer = 'Lomedu Admin'}) {
    final encodedIssuer = Uri.encodeComponent(issuer);
    final encodedEmail = Uri.encodeComponent(email);
    return 'otpauth://totp/$encodedIssuer:$encodedEmail?secret=$secret&issuer=$encodedIssuer';
  }

  /// 2FA beállítása a felhasználó számára
  static Future<String> setupTwoFactorAuth(User user) async {
    final secret = generateSecret();

    await _firestore.collection(_collection).doc(user.uid).set({
      'secret': secret,
      'enabled': false,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'email': user.email,
    });

    return secret;
  }

  /// 2FA aktiválása a felhasználó számára (kód ellenőrzés után)
  static Future<bool> enableTwoFactorAuth(User user, String code) async {
    final doc = await _firestore.collection(_collection).doc(user.uid).get();

    if (!doc.exists) {
      return false;
    }

    final secret = doc.data()?['secret'];
    if (secret == null) {
      return false;
    }

    final isValid = verifyTOTP(secret, code);

    if (isValid) {
      await _firestore.collection(_collection).doc(user.uid).update({
        'enabled': true,
        'activatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }

    return false;
  }

  /// 2FA deaktiválása a felhasználó számára
  static Future<bool> disableTwoFactorAuth(User user, String code) async {
    final doc = await _firestore.collection(_collection).doc(user.uid).get();

    if (!doc.exists) {
      return false;
    }

    final secret = doc.data()?['secret'];
    if (secret == null) {
      return false;
    }

    final isValid = verifyTOTP(secret, code);

    if (isValid) {
      await _firestore.collection(_collection).doc(user.uid).update({
        'enabled': false,
        'disabledAt': FieldValue.serverTimestamp(),
      });
      return true;
    }

    return false;
  }

  /// Ellenőrzés, hogy a felhasználónál aktiválva van-e a 2FA
  static Future<bool> isTwoFactorEnabled(User user) async {
    final doc = await _firestore.collection(_collection).doc(user.uid).get();

    if (!doc.exists) {
      return false;
    }

    return doc.data()?['enabled'] == true;
  }

  /// Felhasználó 2FA beállításainak lekérése
  static Future<Map<String, dynamic>?> getTwoFactorSettings(User user) async {
    final doc = await _firestore.collection(_collection).doc(user.uid).get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  /// 2FA kód ellenőrzése bejelentkezéskor
  static Future<bool> validateLogin(User user, String code) async {
    final doc = await _firestore.collection(_collection).doc(user.uid).get();

    if (!doc.exists) {
      return true; // Ha nincs 2FA beállítva, akkor sikeres a belépés
    }

    final enabled = doc.data()?['enabled'] == true;

    if (!enabled) {
      return true; // Ha nincs aktiválva, akkor sikeres a belépés
    }

    final secret = doc.data()?['secret'];
    if (secret == null) {
      return false;
    }

    return verifyTOTP(secret, code);
  }
}

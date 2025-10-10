import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class DeviceChangeService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Eszközváltási kód igénylése
  static Future<Map<String, dynamic>> requestDeviceChange(String email) async {
    try {
      final callable = _functions.httpsCallable('requestDeviceChange');
      final result = await callable.call({'email': email.trim().toLowerCase()});
      return {'success': true, 'data': result.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Eszközváltási kód ellenőrzése és váltás
  static Future<Map<String, dynamic>> verifyAndChangeDevice({
    required String email,
    required String code,
    required String newFingerprint,
  }) async {
    try {
      debugPrint('=== DEVICE CHANGE DEBUG ===');
      debugPrint('Email: $email');
      debugPrint('Code: $code');
      debugPrint('New Fingerprint: $newFingerprint');

      final callable = _functions.httpsCallable('verifyAndChangeDevice');
      final result = await callable.call({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'fingerprint': newFingerprint,
      });

      debugPrint('Cloud Function result: ${result.data}');
      return {'success': true, 'data': result.data};
    } catch (e) {
      debugPrint('Cloud Function error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

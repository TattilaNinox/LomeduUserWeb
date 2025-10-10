import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceFingerprint {
  /// Webes eszköz ujjlenyomat generálása
  static Future<String> getWebFingerprint() async {
    // Determinisztikus web fingerprint - böngésző jellemzők alapján
    const key = 'device_fingerprint';

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(key);

      if (stored != null && stored.isNotEmpty) {
        debugPrint('DeviceFingerprint: Using stored fingerprint: $stored');
        return stored; // VISSZAADNI a mentett értéket!
      }

      // Új fingerprint generálása - böngésző jellemzők alapján
      final fingerprint = await _generateStableWebFingerprint();
      await prefs.setString(key, fingerprint);
      debugPrint(
          'DeviceFingerprint: Generated new stable fingerprint: $fingerprint');
      return fingerprint;
    } catch (e) {
      // Hiba esetén is új generálás
      final fingerprint = await _generateStableWebFingerprint();
      debugPrint(
          'DeviceFingerprint: Generated fallback fingerprint: $fingerprint');
      return fingerprint;
    }
  }

  /// Stabil web fingerprint generálása
  static Future<String> _generateStableWebFingerprint() async {
    try {
      // Stabil böngésző jellemzők összegyűjtése
      const language = 'hu'; // Magyar nyelv
      const platform = 'web';
      const userAgent = 'flutter_web'; // Stabil érték
      const timezone = 1; // Magyar időzóna (CET/CEST)

      // Kombinált string - NINCS timestamp benne!
      final combined = '${platform}_$timezone_${language}_$userAgent';

      // Hash generálása
      final hash = _simpleHash(combined);

      return 'web_$hash';
    } catch (e) {
      // Hiba esetén is stabil generálás
      return 'web_${_simpleHash('flutter_web_stable')}';
    }
  }

  /// Egyszerű hash függvény
  static int _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0xffffffff;
    }
    return hash.abs();
  }

  /// Android eszköz ujjlenyomat generálása (mint a mobil appban)
  static Future<String> getAndroidFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    return '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}_android';
  }

  /// iOS eszköz ujjlenyomat generálása
  static Future<String> getIOSFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    final iosInfo = await deviceInfo.iosInfo;

    return '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.name}_ios';
  }

  /// Platform-specifikus ujjlenyomat
  static Future<String> getCurrentFingerprint() async {
    if (kIsWeb) {
      return await getWebFingerprint();
    } else if (Platform.isAndroid) {
      return await getAndroidFingerprint();
    } else if (Platform.isIOS) {
      return await getIOSFingerprint();
    } else {
      return 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Webes ujjlenyomat törlése (új generáláshoz)
  static Future<void> clearWebFingerprint() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('device_fingerprint');
        debugPrint('DeviceFingerprint: Cleared stored fingerprint');
      } catch (e) {
        debugPrint('DeviceFingerprint: Failed to clear fingerprint: $e');
      }
    }
  }
}

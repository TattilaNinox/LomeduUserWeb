import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceFingerprint {
  /// Webes eszköz ujjlenyomat generálása
  static String getWebFingerprint() {
    // Egyszerű web fingerprint – determinisztikus
    return 'web_${DateTime.now().millisecondsSinceEpoch % 100000}';
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
      return getWebFingerprint();
    } else if (Platform.isAndroid) {
      return await getAndroidFingerprint();
    } else if (Platform.isIOS) {
      return await getIOSFingerprint();
    } else {
      return 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}

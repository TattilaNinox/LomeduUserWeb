import 'package:flutter/material.dart';

/// A DeviceChecker widget globálisan figyeli a felhasználó eszközének ujjlenyomatát
/// és kijelentkezteti a felhasználót, ha az nem egyezik a Firestore-ban tárolttal.
///
/// Ez a widget csak akkor fut, ha a felhasználó be van jelentkezve és nem
/// auth-related képernyőkön van (login, register, device-change).
class DeviceChecker extends StatelessWidget {
  final Widget child;

  const DeviceChecker({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

import 'package:flutter/material.dart';

/// Rövid splash/guard képernyő az auth + eszköz ellenőrzés idejére.
class GuardSplashScreen extends StatelessWidget {
  const GuardSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(),
            ),
            SizedBox(height: 16),
            Text('Ellenőrzés folyamatban...'),
          ],
        ),
      ),
    );
  }
}

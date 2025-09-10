import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/two_factor_auth.dart';

/// Kétfaktoros hitelesítés beállítási képernyő
class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  TwoFactorAuthScreenState createState() => TwoFactorAuthScreenState();
}

class TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  bool _isLoading = true;
  bool _is2FAEnabled = false;
  String? _secret;
  String? _qrData;
  String? _errorMessage;
  String? _successMessage;
  bool _showSecretKey = false;
  final TextEditingController _otpSetupController = TextEditingController();
  final TextEditingController _otpDisableController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load2FASettings();
  }

  /// 2FA beállítások betöltése
  Future<void> _load2FASettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Nincs bejelentkezett felhasználó.';
          _isLoading = false;
        });
        return;
      }

      final settings = await TwoFactorAuth.getTwoFactorSettings(user);

      if (settings == null) {
        // Ha még nincs beállítva, generálunk egy új titkot
        final secret = await TwoFactorAuth.setupTwoFactorAuth(user);
        final qrData = TwoFactorAuth.getGoogleAuthenticatorUri(
            secret, user.email ?? 'felhasznalo@lomedu.hu');

        setState(() {
          _is2FAEnabled = false;
          _secret = secret;
          _qrData = qrData;
        });
      } else {
        // Ha már van beállítva, betöltjük az adatokat
        final secret = settings['secret'];
        final qrData = TwoFactorAuth.getGoogleAuthenticatorUri(
            secret, user.email ?? 'felhasznalo@lomedu.hu');

        setState(() {
          _is2FAEnabled = settings['enabled'] == true;
          _secret = secret;
          _qrData = qrData;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hiba történt a beállítások betöltése során: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 2FA aktiválása
  Future<void> _enable2FA(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Nincs bejelentkezett felhasználó.';
        });
        return;
      }

      final result = await TwoFactorAuth.enableTwoFactorAuth(user, code);

      if (result) {
        setState(() {
          _is2FAEnabled = true;
          _successMessage = 'A kétfaktoros hitelesítés sikeresen aktiválva!';
        });
      } else {
        setState(() {
          _errorMessage = 'Érvénytelen kód. Próbáld újra!';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hiba történt az aktiválás során: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 2FA kikapcsolása
  Future<void> _disable2FA(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Nincs bejelentkezett felhasználó.';
        });
        return;
      }

      final result = await TwoFactorAuth.disableTwoFactorAuth(user, code);

      if (result) {
        setState(() {
          _is2FAEnabled = false;
          _successMessage = 'A kétfaktoros hitelesítés sikeresen kikapcsolva!';
        });
      } else {
        setState(() {
          _errorMessage = 'Érvénytelen kód. Próbáld újra!';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hiba történt a kikapcsolás során: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Titkos kulcs másolása a vágólapra
  void _copySecretToClipboard() {
    if (_secret != null) {
      Clipboard.setData(ClipboardData(text: _secret!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titkos kulcs a vágólapra másolva!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kétfaktoros hitelesítés'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Állapot megjelenítése
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _is2FAEnabled
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _is2FAEnabled ? Colors.green : Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _is2FAEnabled
                                  ? Icons.security
                                  : Icons.security_outlined,
                              color: _is2FAEnabled ? Colors.green : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _is2FAEnabled
                                        ? 'Kétfaktoros hitelesítés bekapcsolva'
                                        : 'Kétfaktoros hitelesítés kikapcsolva',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _is2FAEnabled
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _is2FAEnabled
                                        ? 'Fiókod további védelmet kap minden bejelentkezéskor.'
                                        : 'Kapcsold be a kétfaktoros hitelesítést a fiókod védelme érdekében.',
                                    style: TextStyle(
                                      color: _is2FAEnabled
                                          ? Colors.green.shade800
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Hibaüzenet megjelenítése
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Sikeres művelet üzenet megjelenítése
                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: Colors.green),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (!_is2FAEnabled) ...[
                        // Beállítási útmutató
                        const Text(
                          'A kétfaktoros hitelesítés beállítása',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          '1. Telepítsd a Google Authenticator alkalmazást a telefonodra',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.android),
                              label: const Text('Android letöltés'),
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.apple),
                              label: const Text('iOS letöltés'),
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          '2. Olvasd be a QR-kódot az alkalmazással',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),

                        // QR kód megjelenítése
                        if (_qrData != null) ...[
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: QrImageView(
                                data: _qrData!,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Titkos kulcs megjelenítése
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'Vagy add hozzá manuálisan a titkos kulcsot:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _showSecretKey = !_showSecretKey;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _showSecretKey
                                              ? _secret ?? 'N/A'
                                              : '••••••••••••••••••••',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          _showSecretKey
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Másolás'),
                                  onPressed: _copySecretToClipboard,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          const Text(
                            '3. Írd be az alkalmazás által generált kódot',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),

                          Builder(
                            builder: (context) {
                              final defaultPinTheme = PinTheme(
                                width: 44,
                                height: 48,
                                textStyle: const TextStyle(fontSize: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFF1E3A8A)),
                                ),
                              );
                              return Pinput(
                                length: 6,
                                controller: _otpSetupController,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                defaultPinTheme: defaultPinTheme,
                                focusedPinTheme: defaultPinTheme.copyWith(
                                  decoration:
                                      defaultPinTheme.decoration!.copyWith(
                                    border: Border.all(
                                        color: const Color(0xFF1E3A8A),
                                        width: 2),
                                  ),
                                ),
                                onCompleted: _enable2FA,
                                onSubmitted: _enable2FA,
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.security),
                              label: const Text(
                                  'Kétfaktoros hitelesítés aktiválása'),
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      // A kód beírása után az onSubmit hívódik meg
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],

                      // Ha már be van kapcsolva a 2FA, akkor kikapcsolási lehetőség
                      if (_is2FAEnabled) ...[
                        const Text(
                          'Kétfaktoros hitelesítés kikapcsolása',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Írd be a Google Authenticator által generált kódot a kikapcsoláshoz:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final defaultPinTheme = PinTheme(
                              width: 44,
                              height: 48,
                              textStyle: const TextStyle(fontSize: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red),
                              ),
                            );
                            return Pinput(
                              length: 6,
                              controller: _otpDisableController,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              defaultPinTheme: defaultPinTheme,
                              focusedPinTheme: defaultPinTheme.copyWith(
                                decoration:
                                    defaultPinTheme.decoration!.copyWith(
                                  border:
                                      Border.all(color: Colors.red, width: 2),
                                ),
                              ),
                              onCompleted: _disable2FA,
                              onSubmitted: _disable2FA,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.security_update_warning),
                            label: const Text(
                                'Kétfaktoros hitelesítés kikapcsolása'),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    // A kód beírása után az onSubmit hívódik meg
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Visszatérés a beállításokhoz gomb
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Vissza'),
                          onPressed: () => context.go('/notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

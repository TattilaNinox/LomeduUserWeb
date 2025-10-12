import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../core/session_guard.dart';

/// A bejelentkezési képernyőt megvalósító widget.
///
/// Ez egy `StatefulWidget`, mivel a beviteli mezők tartalmát, a jelszó
/// láthatóságát és a hibaüzeneteket az állapotában (`State`) kell kezelnie.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  LoginScreenState createState() => LoginScreenState();
}

/// A `LoginScreen` widget állapotát kezelő osztály.
class LoginScreenState extends State<LoginScreen> {
  // A beviteli mezők vezérlői (controller), amelyekkel elérhető és módosítható
  // a mezők tartalma.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  // Magyar Firebase Auth hibaüzenetek
  static const Map<String, String> _firebaseErrorHu = {
    'wrong-password': 'Helytelen jelszó.',
    'user-not-found': 'Ez az e-mail cím nem szerepel a rendszerben.',
    'invalid-email': 'Érvénytelen e-mail cím formátum.',
    'user-disabled': 'A fiók le lett tiltva.',
    'too-many-requests':
        'Túl sok sikertelen próbálkozás. Kérlek, próbáld meg később.',
    'invalid-credential': 'A megadott bejelentkezési adatok helytelenek.',
  };

  // Egy állapotváltozó a bejelentkezési hibaüzenetek tárolására.
  // Ha értéke `null`, nem jelenik meg hibaüzenet.
  String? _errorMessage;

  /// A bejelentkezési folyamatot kezelő aszinkron metódus.
  Future<void> _signIn() async {
    try {
      debugPrint('=== BEJELENTKEZÉS KEZDETE ===');
      debugPrint('Email: ${_emailController.text.trim()}');
      debugPrint('Password length: ${_passwordController.text.trim().length}');

      setState(() {
        _errorMessage = null;
      });

      // Megpróbál bejelentkezni a Firebase Authentication szolgáltatással,
      // az e-mail és jelszó mezők aktuális értékét használva.
      // A `.trim()` metódus eltávolítja a felesleges szóközöket a szöveg elejéről és végéről.
      debugPrint('Firebase Auth bejelentkezés megkezdése...');
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      debugPrint('Firebase Auth bejelentkezés sikeres!');

      // Sikeres bejelentkezés után azonnali irányítás a guard állapot alapján
      if (userCredential.user != null) {
        debugPrint('Bejelentkezés sikeres, guard állapot ellenőrzése...');
        await SessionGuard.instance.ensureInitialized();
        final auth = SessionGuard.instance.authStatus;
        final device = SessionGuard.instance.deviceAccess;

        if (!mounted) return;
        if (auth == AuthStatus.emailUnverified) {
          context.go('/verify-email');
          return;
        }
        if (device == DeviceAccess.denied) {
          context.go('/device-change');
          return;
        }
        if (device == DeviceAccess.loading) {
          context.go('/guard');
          return;
        }
        // allowed esetben a redirect úgyis /notes-ra visz, nem kell tenni semmit
      }
    } on FirebaseAuthException catch (e) {
      // Ha a bejelentkezés során a Firebase hibát dob (pl. rossz jelszó),
      // akkor a `catch` blokk lefut.
      // A `setState` metódus frissíti a widget állapotát, és beállítja a
      // hibaüzenetet, ami ezután megjelenik a UI-n.
      setState(() {
        _errorMessage = _firebaseErrorHu[e.code] ?? 'Ismeretlen hiba történt.';
      });
    } on TypeError catch (e) {
      debugPrint("MFA TypeError during login (nem kritikus): $e");
      setState(() {
        _errorMessage = 'Bejelentkezési hiba történt. Kérlek próbáld újra.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Hiba történt a bejelentkezés során: $e';
      });
    }
  }

  /// A widget életciklusának `dispose` metódusa.
  ///
  /// Akkor hívódik meg, amikor a widget véglegesen eltávolításra kerül a
  /// widget-fáról. Itt kell felszabadítani az erőforrásokat, mint például
  /// a `TextEditingController`-eket, hogy elkerüljük a memóriaszivárgást.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// A widget felhasználói felületét (UI) felépítő metódus.
  @override
  Widget build(BuildContext context) {
    // A `Scaffold` egy alapvető Material Design vizuális elrendezési struktúra.
    // Ha a verifikációs linkről jöttünk (web), jelzünk a másik fülnek
    if (kIsWeb) {
      final qp = Uri.base.queryParameters;
      // Eszközváltásból visszatérve előtöltjük az e-mailt, ha üres
      final prefillEmail = widget.initialEmail ?? qp['email'];
      if (prefillEmail != null && prefillEmail.isNotEmpty &&
          _emailController.text.isEmpty) {
        _emailController.text = prefillEmail;
      }
      if (qp['from'] == 'verify') {
        try {
          // Web BroadcastChannel JS API hívása dart:js használatával
          // ignore: avoid_dynamic_calls
          final channel =
              js.context['BroadcastChannel'].callMethod('new', ['lomedu-auth']);
          channel.callMethod('postMessage', ['email-verified']);
        } catch (_) {}
      }
    } else {
      // Nem web környezet: az átadott initialEmail-t használjuk, ha van
      final prefillEmail = widget.initialEmail;
      if (prefillEmail != null && prefillEmail.isNotEmpty &&
          _emailController.text.isEmpty) {
        _emailController.text = prefillEmail;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // Görgethető, biztonságos terület a kisebb kijelzők és a billentyűzet miatt.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            // A bejelentkezési panel konténere.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // A `Column` widget a gyermekeit függőlegesen rendezi el.
                child: Column(
                  // A `mainAxisSize: MainAxisSize.min` biztosítja, hogy a `Column`
                  // csak annyi helyet foglaljon, amennyi a tartalmához szükséges.
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cím
                    Image.asset(
                      'assets/images/login_LOGO.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lomedu Belépés',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // E-mail beviteli mező
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon:
                            const Icon(Icons.email, color: Color(0xFF6B7280)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 16),
                    // Jelszó beviteli mező
                    TextField(
                      controller: _passwordController,
                      obscureText:
                          !_passwordVisible, // Elrejti a beírt karaktereket
                      decoration: InputDecoration(
                        labelText: 'Jelszó',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFF6B7280)),
                        ),
                        prefixIcon:
                            const Icon(Icons.lock, color: Color(0xFF6B7280)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                      ),
                      autofillHints: const [AutofillHints.password],
                    ),
                    // Hibaüzenet megjelenítése, ha van.
                    // A feltételes `if` a collection-ön belül csak akkor adja hozzá
                    // a `SizedBox`-ot és a `Text`-et a widget-listához, ha az
                    // `_errorMessage` nem `null`.
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!, // A `!` jelzi, hogy biztosak vagyunk benne, itt már nem `null`.
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE74C3C),
                          fontSize: 14,
                        ),
                      ),
                      if (_errorMessage!.contains('nincs regisztrálva')) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Ha új böngészőt használsz vagy törölted a sütiket, használd az Eszközváltás gombot.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFE74C3C),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    // Bejelentkezés gomb
                    ElevatedButton(
                      onPressed:
                          _signIn, // A gomb lenyomásakor a `_signIn` metódus hívódik meg.
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Bejelentkezés',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          child: const Text('Elfelejtett jelszó?'),
                        ),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('Regisztráció'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        context.go('/device-change');
                      },
                      icon: const Icon(
                        Icons.devices,
                        size: 16,
                        color: Color(0xFF1E3A8A),
                      ),
                      label: const Text('Eszköz regisztráció'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

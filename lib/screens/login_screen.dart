import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A bejelentkezési képernyőt megvalósító widget.
///
/// Ez egy `StatefulWidget`, mivel a beviteli mezők tartalmát, a jelszó
/// láthatóságát és a hibaüzeneteket az állapotában (`State`) kell kezelnie.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

/// A `LoginScreen` widget állapotát kezelő osztály.
class LoginScreenState extends State<LoginScreen> {
  // A beviteli mezők vezérlői (controller), amelyekkel elérhető és módosítható
  // a mezők tartalma. A fejlesztés megkönnyítése érdekében előre ki vannak
  // töltve teszt adatokkal.
  final _emailController = TextEditingController(text: 'tattila.ninox@gmail.com');
  final _passwordController = TextEditingController(text: 'Tolgyesi88');

  // Egy állapotváltozó a bejelentkezési hibaüzenetek tárolására.
  // Ha értéke `null`, nem jelenik meg hibaüzenet.
  String? _errorMessage;

  /// A bejelentkezési folyamatot kezelő aszinkron metódus.
  Future<void> _signIn() async {
    try {
      // Megpróbál bejelentkezni a Firebase Authentication szolgáltatással,
      // az e-mail és jelszó mezők aktuális értékét használva.
      // A `.trim()` metódus eltávolítja a felesleges szóközöket a szöveg elejéről és végéről.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Sikeres bejelentkezés után ellenőrzi, hogy a widget még a fán van-e
      // (`mounted` tulajdonság), mielőtt navigálna. Ez megakadályozza a hibákat,
      // ha a felhasználó időközben elnavigálna az oldalról.
      if (mounted) {
        // A `go_router` segítségével átirányítja a felhasználót a főoldalra ('/notes').
        context.go('/notes');
      }
    } on FirebaseAuthException catch (e) {
      // Ha a bejelentkezés során a Firebase hibát dob (pl. rossz jelszó),
      // akkor a `catch` blokk lefut.
      // A `setState` metódus frissíti a widget állapotát, és beállítja a
      // hibaüzenetet, ami ezután megjelenik a UI-n.
      setState(() {
        _errorMessage = e.message;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // A `Center` widget a gyermekét (a bejelentkezési panelt) középre igazítja.
      body: Center(
        // A bejelentkezési panel konténere.
        child: Container(
          width: 500,
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
              const Text(
                'Lomedu Admin',
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
                    borderSide: const BorderSide(color: Color(0xFF6B7280)),
                  ),
                  prefixIcon: const Icon(Icons.email, color: Color(0xFF6B7280)),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              // Jelszó beviteli mező
              TextField(
                controller: _passwordController,
                obscureText: true, // Elrejti a beírt karaktereket
                decoration: InputDecoration(
                  labelText: 'Jelszó',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF6B7280)),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF6B7280)),
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
                  style: const TextStyle(
                    color: Color(0xFFE74C3C),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Bejelentkezés gomb
              ElevatedButton(
                onPressed: _signIn, // A gomb lenyomásakor a `_signIn` metódus hívódik meg.
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

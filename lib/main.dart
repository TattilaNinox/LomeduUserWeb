import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/firebase_config.dart';
import 'screens/login_screen.dart';
import 'core/app_messenger.dart';
import 'screens/note_list_screen.dart';
// Felhasználói nézetben az admin képernyők eltávolítva
// import 'screens/registration_screen.dart';
// import 'screens/forgot_password_screen.dart';
// importok eltávolítva: bundle, create/edit képernyők
import 'theme/app_theme.dart'; // <-- AppTheme importálása
// flashcard/kvíz admin képernyők eltávolítva
import 'screens/verify_otp_screen.dart';
// import 'screens/two_factor_auth_screen.dart';
// public doc admin képernyők eltávolítva
import 'screens/note_read_screen.dart';
import 'screens/flashcard_deck_view_screen.dart';
import 'screens/interactive_note_view_screen.dart';
import 'screens/dynamic_quiz_view_screen.dart';

/// Az alkalmazás fő belépési pontja.
void main() async {
  // Biztosítja, hogy a Flutter widget-kötések inicializálva legyenek,
  // mielőtt bármilyen Flutter-specifikus API hívás történne.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializálja a Firebase szolgáltatásokat az alkalmazás indulásakor.
  // Ez egy aszinkron művelet, ezért a `main` függvény `async`-ként van megjelölve.
  await FirebaseConfig.initialize();

  // Elindítja az alkalmazást a gyökér widget (`MyApp`) megadásával.
  runApp(const MyApp());
}

/// Az alkalmazás navigációs útvonalait kezeli a `go_router` csomag segítségével.
/// Ez a router határozza meg, hogy melyik URL (útvonal) melyik képernyőt (widgetet) töltse be.
final _router = GoRouter(
  // A kezdő útvonal, ahova az alkalmazás induláskor navigál.
  initialLocation: '/login',
  // Az alkalmazásban elérhető útvonalak listája.
  routes: [
    // Bejelentkezési képernyő útvonala.
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Felhasználói appban a regisztráció/jelszó elfelejtése elrejtve (ha nem kell)
    // Jegyzetek listájának képernyője.
    GoRoute(
      path: '/notes',
      builder: (context, state) {
        final qp = state.uri.queryParameters;
        return NoteListScreen(
          initialSearch: qp['q'],
          initialStatus: qp['status'],
          initialCategory: qp['category'],
          initialScience: qp['science'],
          initialTag: qp['tag'],
          initialType: qp['type'],
        );
      },
    ),
    // Létrehozó/szerkesztő útvonalak eltávolítva
    // Kvíz admin útvonalak eltávolítva
    // Admin listák/kezelők eltávolítva
    // Admin note pages nézet eltávolítva
    // Felhasználói, csak olvasási nézet a szöveges jegyzethez (admin funkciók nélkül)
    GoRoute(
      path: '/read/note/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return NoteReadScreen(noteId: noteId);
      },
    ),
    // Kompatibilitási útvonal: /note/:noteId -> felhasználói olvasó nézet
    GoRoute(
      path: '/note/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return NoteReadScreen(noteId: noteId);
      },
    ),
    // Interaktív jegyzet megtekintése
    GoRoute(
      path: '/interactive-note/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return InteractiveNoteViewScreen(noteId: noteId, from: null);
      },
    ),
    GoRoute(
      path: '/quiz/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return DynamicQuizViewScreen(noteId: noteId);
      },
    ),
    // Interaktív jegyzet megtekintés megmaradhat, ha kell – külön request esetén visszahozzuk
    // Szerkesztés útvonal eltávolítva
    // További admin útvonalak eltávolítva
    // Kétfaktoros hitelesítési kód ellenőrzése
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) => const VerifyOtpScreen(),
    ),
    // Flashcard deck megtekintés útvonal (csak olvasás)
    GoRoute(
      path: '/deck/:deckId/view',
      builder: (context, state) {
        final deckId = state.pathParameters['deckId']!;
        return FlashcardDeckViewScreen(deckId: deckId);
      },
    ),
  ],
);

/// Az alkalmazás gyökér widgetje.
///
/// Ez az osztály felelős a `MaterialApp` beállításáért, amely az egész
/// alkalmazás alapját képezi, beleértve a témát és a navigációt.
class MyApp extends StatelessWidget {
  /// A `MyApp` widget konstruktora.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // A `MaterialApp.router` a `go_router` használatához szükséges.
    // Ez köti össze a router konfigurációt az alkalmazás vizuális rétegével.
    return MaterialApp.router(
      title: 'Lomedu Admin',
      // Az alkalmazás központi vizuális témájának beállítása.
      theme: AppTheme.lightTheme,
      // A "debug" szalag eltávolítása a jobb felső sarokból.
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.key,
      // A korábban definiált router konfiguráció átadása az alkalmazásnak.
      routerConfig: _router,
    );
  }
}

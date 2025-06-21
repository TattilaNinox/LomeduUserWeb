import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/firebase_config.dart';
import 'screens/login_screen.dart';
import 'screens/note_list_screen.dart';
import 'screens/note_pages_screen.dart';
import 'screens/interactive_note_create_screen.dart';
import 'screens/category_manager_screen.dart';
import 'screens/interactive_note_view_screen.dart';
import 'screens/note_edit_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/bundle_list_screen.dart';
import 'screens/bundle_edit_screen.dart';
import 'screens/bundle_view_screen.dart';
import 'theme/app_theme.dart'; // <-- AppTheme importálása

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
    // Regisztrációs képernyő útvonala.
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegistrationScreen(),
    ),
    // Elfelejtett jelszó képernyő útvonala.
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    // Jegyzetek listájának képernyője.
    GoRoute(
      path: '/notes',
      builder: (context, state) => const NoteListScreen(),
    ),
    // Új interaktív jegyzet létrehozása képernyő.
    GoRoute(
      path: '/interactive-notes/create',
      builder: (context, state) => const InteractiveNoteCreateScreen(),
    ),
    // Kategóriakezelő képernyő.
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoryManagerScreen(),
    ),
    // Kötegek listája képernyő.
    GoRoute(
      path: '/bundles',
      builder: (context, state) => const BundleListScreen(),
    ),
    // Új köteg létrehozása képernyő.
    GoRoute(
      path: '/bundles/create',
      builder: (context, state) => const BundleEditScreen(),
    ),
    // Köteg szerkesztése képernyő.
    GoRoute(
      path: '/bundles/edit/:bundleId',
      builder: (context, state) {
        final bundleId = state.pathParameters['bundleId']!;
        return BundleEditScreen(bundleId: bundleId);
      },
    ),
    // Köteg megtekintése prezentáció módban.
    GoRoute(
      path: '/bundles/view/:bundleId',
      builder: (context, state) {
        final bundleId = state.pathParameters['bundleId']!;
        return BundleViewScreen(bundleId: bundleId);
      },
    ),
    // Egy konkrét jegyzet oldalainak megjelenítése.
    // A `:noteId` egy dinamikus paraméter, ami az adott jegyzet azonosítóját jelöli.
    GoRoute(
      path: '/note/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        // A 'from' query paraméter kiolvasása
        final from = state.uri.queryParameters['from'];
        return NotePagesScreen(noteId: noteId, from: from);
      },
    ),
    // Egy konkrét interaktív jegyzet megtekintése.
    GoRoute(
      path: '/interactive-note/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        // A 'from' query paraméter kiolvasása
        final from = state.uri.queryParameters['from'];
        return InteractiveNoteViewScreen(noteId: noteId, from: from);
      },
    ),
    // Egy konkrét jegyzet szerkesztése.
    GoRoute(
      path: '/note/edit/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return NoteEditScreen(noteId: noteId);
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
      title: 'Lomed Admin',
      // Az alkalmazás központi vizuális témájának beállítása.
      theme: AppTheme.lightTheme,
      // A "debug" szalag eltávolítása a jobb felső sarokból.
      debugShowCheckedModeBanner: false,
      // A korábban definiált router konfiguráció átadása az alkalmazásnak.
      routerConfig: _router,
    );
  }
}

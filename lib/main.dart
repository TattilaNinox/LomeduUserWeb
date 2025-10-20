import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/firebase_config.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'core/app_messenger.dart';
import 'screens/note_list_screen.dart';
// Felhasználói nézetben az admin képernyők eltávolítva
// import 'screens/registration_screen.dart';
// import 'screens/forgot_password_screen.dart';
// importok eltávolítva: bundle, create/edit képernyők
import 'theme/app_theme.dart'; // <-- AppTheme importálása
// flashcard/kvíz admin képernyők eltávolítva
// import 'screens/verify_otp_screen.dart'; // 2FA csak az admin webben
import 'screens/verify_email_screen.dart';
import 'screens/device_change_screen.dart';
// import 'screens/two_factor_auth_screen.dart';
// public doc admin képernyők eltávolítva
import 'screens/note_read_screen.dart';
import 'screens/flashcard_deck_view_screen.dart';
import 'screens/flashcard_study_screen.dart';
import 'screens/interactive_note_view_screen.dart';
import 'screens/dynamic_quiz_view_screen.dart';
import 'core/session_guard.dart';
import 'screens/guard_splash_screen.dart';
import 'screens/account_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/web_subscription_screen.dart';

/// Az alkalmazás fő belépési pontja.
void main() async {
  // Biztosítja, hogy a Flutter widget-kötések inicializálva legyenek,
  // mielőtt bármilyen Flutter-specifikus API hívás történne.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializálja a Firebase szolgáltatásokat az alkalmazás indulásakor.
  // Ez egy aszinkron művelet, ezért a `main` függvény `async`-ként van megjelölve.
  await FirebaseConfig.initialize();
  // Initialize intl date formatting for Hungarian locale
  await initializeDateFormatting('hu', null);

  // Elindítja az alkalmazást a gyökér widget (`MyApp`) megadásával.
  runApp(const MyApp());
}

/// Az alkalmazás navigációs útvonalait kezeli a `go_router` csomag segítségével.
/// Ez a router határozza meg, hogy melyik URL (útvonal) melyik képernyőt (widgetet) töltse be.
final _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: SessionGuard.instance,
  redirect: (context, state) {
    // Gondoskodunk róla, hogy a guard inicializálva legyen
    SessionGuard.instance.ensureInitialized();

    final auth = SessionGuard.instance.authStatus;
    final device = SessionGuard.instance.deviceAccess;
    final loc = state.uri.path;
    final qp = state.uri.queryParameters;
    final baseQp = Uri.base.queryParameters; // query a hash előttről
    final shouldUseBaseParams = {
      '/',
      '/verify-email',
      '/reset-password',
    }.contains(loc);
    final modeParam =
        qp['mode'] ?? (shouldUseBaseParams ? baseQp['mode'] : null);
    final codeParam =
        qp['oobCode'] ?? (shouldUseBaseParams ? baseQp['oobCode'] : null);
    final isAuthRoute = {
      '/login',
      '/register',
      '/verify-email',
      '/guard',
      '/device-change',
      '/forgot-password',
      '/reset-password',
    }.contains(loc);

    if (loc == '/login') {
      // Már a login oldalon vagyunk: ne fussanak az email-link redirectek, különben hurok lesz
      // (mode=oobCode a base URL-ben még megmaradt)
      return null;
    }
    // Firebase action linkek kezelése bárhonnan (függetlenül a hash útvonaltól)
    // verifyEmail
    if (loc != '/verify-email' &&
        modeParam == 'verifyEmail' &&
        codeParam != null) {
      final code = codeParam;
      return '/verify-email?mode=verifyEmail&oobCode=$code';
    }
    // resetPassword
    if (loc != '/reset-password' &&
        modeParam == 'resetPassword' &&
        codeParam != null) {
      final code = codeParam;
      return '/reset-password?mode=resetPassword&oobCode=$code';
    }

    // Ha a gyári email link a gyökérre érkezik ("/"), query-ben oobCode-dal,
    // akkor tereljük át a megfelelő saját képernyőnkre. (visszafelé kompatibilitás)
    // verifyEmail
    if (loc == '/' && modeParam == 'verifyEmail' && codeParam != null) {
      final code = codeParam;
      return '/verify-email?mode=verifyEmail&oobCode=$code';
    }
    // resetPassword
    if (loc == '/' && modeParam == 'resetPassword' && codeParam != null) {
      final code = codeParam;
      return '/reset-password?mode=resetPassword&oobCode=$code';
    }

    if (auth == AuthStatus.loggedOut) {
      final publicRoutes = {
        '/login',
        '/register',
        '/device-change',
        '/forgot-password',
        '/reset-password',
      };
      return publicRoutes.contains(loc) ? null : '/login';
    }

    if (auth == AuthStatus.emailUnverified) {
      return loc == '/verify-email' ? null : '/verify-email';
    }

    if (device == DeviceAccess.loading) {
      return loc == '/guard' ? null : '/guard';
    }

    if (device == DeviceAccess.denied) {
      return loc == '/device-change' ? null : '/device-change';
    }

    if (isAuthRoute) {
      return '/notes';
    }

    return null;
  },
  routes: [
    // Bejelentkezési képernyő útvonala.
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final qp = state.uri.queryParameters;
        return LoginScreen(initialEmail: qp['email']);
      },
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const WebSubscriptionScreen(),
    ),
    // Reset password képernyő (oobCode query param kezelése)
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final qpLocal = state.uri.queryParameters;
        final code = qpLocal['oobCode'] ?? Uri.base.queryParameters['oobCode'];
        if (code == null || code.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Hiányzó vagy érvénytelen visszaállító kód.'),
              ),
            ),
          );
        }
        return ResetPasswordScreen(oobCode: code);
      },
    ),
    // Regisztrációs képernyő útvonala.
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegistrationScreen(),
    ),
    // Verify email képernyő
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const VerifyEmailScreen(),
    ),
    // Guard / splash képernyő
    GoRoute(
      path: '/guard',
      builder: (context, state) => const GuardSplashScreen(),
    ),
    // Eszközváltás képernyő
    GoRoute(
      path: '/device-change',
      builder: (context, state) => const DeviceChangeScreen(),
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
    // 2FA route eltávolítva a felhasználói webből
    // Flashcard deck megtekintés útvonal (csak olvasás)
    GoRoute(
      path: '/deck/:deckId/view',
      builder: (context, state) {
        final deckId = state.pathParameters['deckId']!;
        return FlashcardDeckViewScreen(deckId: deckId);
      },
    ),
    // Flashcard deck tanulás útvonal
    GoRoute(
      path: '/deck/:deckId/study',
      builder: (context, state) {
        final deckId = state.pathParameters['deckId']!;
        return FlashcardStudyScreen(deckId: deckId);
      },
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
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
    // A DeviceChecker wrappert kivesszük: a router redirect dönti el a képernyőt
    return MaterialApp.router(
      title: 'Lomedu.hu',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.key,
      routerConfig: _router,
    );
  }
}

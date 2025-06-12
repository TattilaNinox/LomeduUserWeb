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
import 'theme/app_theme.dart'; // <-- AppTheme importálása

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initialize();
  runApp(const MyApp());
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/notes',
      builder: (context, state) => const NoteListScreen(),
    ),
    GoRoute(
      path: '/interactive-notes/create',
      builder: (context, state) => const InteractiveNoteCreateScreen(),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoryManagerScreen(),
    ),
    GoRoute(
      path: '/note/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return NotePagesScreen(noteId: noteId);
      },
    ),
    GoRoute(
      path: '/interactive-note/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return InteractiveNoteViewScreen(noteId: noteId);
      },
    ),
    GoRoute(
      path: '/note/edit/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return NoteEditScreen(noteId: noteId);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OrLomed Admin',
      theme: AppTheme.lightTheme, // <-- Központi téma használata
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

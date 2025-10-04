import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// Az alkalmazás oldalsó menüsávját (sidebar) megvalósító widget.
///
/// Ez egy `StatelessWidget`, mivel a saját állapotát nem változtatja meg;
/// a megjelenése kizárólag a konstruktorban kapott `selectedMenu`
/// paramétertől függ. Felelős a fő navigációs linkek és a kijelentkezés
/// gomb megjelenítéséért.
class Sidebar extends StatelessWidget {
  /// Annak a menüpontnak az azonosítója, amelyik éppen aktív.
  /// Ezt a szülő widget adja át, és ez határozza meg, hogy melyik
  /// menüpont lesz vizuálisan kiemelve.
  final String selectedMenu;

  /// A `Sidebar` widget konstruktora.
  const Sidebar({super.key, required this.selectedMenu});

  /// A kijelentkezési logikát kezelő privát metódus.
  Future<void> _signOut(BuildContext context) async {
    // Kijelentkezteti a felhasználót a Firebase Authentication szolgáltatásból.
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    // A `go_router` segítségével a bejelentkezési képernyőre navigál.
    // A `go` metódus törli a navigációs vermet, így a felhasználó
    // nem tud visszalépni az előző oldalra a böngésző "vissza" gombjával.
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Egy fix szélességű konténer, ami a menüsáv alapját képezi.
    return Container(
      width: 200,
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () => context.go('/notes'),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Lomedu Admin',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
            ),
            _buildMenuItem(
                context, 'notes', 'Jegyzetek Listája', selectedMenu == 'notes'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(color: const Color(0xFF1E3A8A).withAlpha(77)),
            ),
            // Felhasználói nézet: admin menük eltávolítva
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF6B7280)),
              title: const Text(
                'Kijelentkezés',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280)),
              ),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Egyetlen menüpontot felépítő segédmetódus.
  ///
  /// Ez a metódus a kapott paraméterek alapján létrehoz egy `ListTile` widgetet,
  /// ami egy navigációs menüpontként funkcionál.
  ///
  /// [context] A widget build kontextusa.
  /// [routeName] A menüponthoz tartozó útvonal azonosítója.
  /// [title] A menüponton megjelenő szöveg.
  /// [isSelected] Igaz, ha ez a menüpont van éppen kiválasztva.
  Widget _buildMenuItem(
      BuildContext context, String routeName, String title, bool isSelected) {
    // A `routeName` alapján kiválasztja a megfelelő ikont.
    final IconData iconData;
    switch (routeName) {
      case 'notes':
        iconData = Icons.list_alt;
        break;
      case 'note_create':
        iconData = Icons.note_add;
        break;
      case 'interactive_note_create':
        iconData = Icons.web;
        break;
      case 'dynamic_quiz_create':
        iconData = Icons.quiz;
        break;
      case 'dynamic_quiz_dual_create':
        iconData = Icons.quiz_outlined;
        break;
      case 'bundles':
        iconData = Icons.collections_bookmark;
        break;
      case 'question_banks':
        iconData = Icons.quiz;
        break;
      case 'subjects':
        iconData = Icons.school;
        break;
      case 'sciences':
        iconData = Icons.science;
        break;
      case 'categories':
        iconData = Icons.category;
        break;
      case 'decks':
        iconData = Icons.style;
        break;
      case 'users':
        iconData = Icons.people;
        break;
      case 'public_documents':
        iconData = Icons.article;
        break;
      default:
        iconData = Icons.error;
    }

    // A `ListTile` egy kényelmes widget sorok létrehozására, amelyek
    // általában ikont, szöveget és egy kattintási eseményt tartalmaznak.
    return ListTile(
      leading: Icon(iconData,
          color:
              isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF6B7280)),
      title: Text(
        title,
        // A stílus (szín, vastagság) a `isSelected` állapottól függően változik.
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF6B7280),
        ),
      ),
      // A háttérszín is a `isSelected` állapottól függ.
      tileColor: isSelected ? Colors.black.withAlpha(51) : Colors.transparent,
      // A `onTap` esemény a `go_router` segítségével a megfelelő útvonalra navigál.
      onTap: () {
        if (routeName == 'notes') {
          context.go('/notes');
        } else if (routeName == 'note_create') {
          context.go('/notes/create');
        } else if (routeName == 'interactive_note_create') {
          context.go('/interactive-notes/create');
        } else if (routeName == 'dynamic_quiz_create') {
          context.go('/dynamic-quiz/create');
        } else if (routeName == 'dynamic_quiz_dual_create') {
          context.go('/dynamic-quiz-dual/create');
        } else if (routeName == 'bundles') {
          context.go('/bundles');
        } else if (routeName == 'question_banks') {
          context.go('/question-banks');
        } else if (routeName == 'categories') {
          context.go('/categories');
        } else if (routeName == 'sciences') {
          context.go('/sciences');
        } else if (routeName == 'decks') {
          context.go('/decks');
        } else if (routeName == 'users') {
          context.go('/users');
        } else if (routeName == 'public_documents') {
          context.go('/public-documents');
        }
      },
    );
  }
}

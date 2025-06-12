import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';
import 'package:go_router/go_router.dart';

class Sidebar extends StatelessWidget {
  final String selectedMenu;

  const Sidebar({super.key, required this.selectedMenu});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.white,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'OrLomed Admin',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          _buildMenuItem(context, 'notes', 'Jegyzetek', selectedMenu == 'notes'),
          _buildMenuItem(context, 'interactive_notes', 'Interaktív Jegyzetek', selectedMenu == 'interactive_notes'),
          _buildMenuItem(context, 'categories', 'Kategóriák', selectedMenu == 'categories'),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            title: const Text(
              'Kijelentkezés',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
            ),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String routeName, String title, bool isSelected) {
    final IconData iconData;
    switch (routeName) {
      case 'notes':
        iconData = Icons.note;
        break;
      case 'interactive_notes':
        iconData = Icons.dynamic_feed;
        break;
      case 'categories':
        iconData = Icons.category;
        break;
      default:
        iconData = Icons.error;
    }
    
    return ListTile(
      leading: Icon(iconData, color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF6B7280)),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF6B7280),
        ),
      ),
      tileColor: isSelected ? Colors.black.withOpacity(0.2) : Colors.transparent,
      onTap: () {
        if (routeName == 'notes') {
          context.go('/notes');
        } else if (routeName == 'interactive_notes') {
          context.go('/interactive-notes/create');
        } else if (routeName == 'categories') {
          context.go('/categories');
        }
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../screens/note_create_screen.dart';

class Header extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;

  const Header({super.key, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: 250,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Keresés...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Adminisztrátor',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NoteCreateScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Új jegyzet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

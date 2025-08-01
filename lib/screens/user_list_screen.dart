import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Felhasználók'),
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'users'),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final email = data['email'] ?? 'Ismeretlen email';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final createdDate = createdAt?.toDate().toString().split(' ')[0] ?? 'Ismeretlen dátum';
                    
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(email),
                      subtitle: Text('Regisztráció: $createdDate'),
                      trailing: const Icon(Icons.info_outline),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

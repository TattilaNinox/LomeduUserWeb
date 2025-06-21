import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';

class DeckListScreen extends StatelessWidget {
  const DeckListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanulókártya Kötegek'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                final newDeckRef = FirebaseFirestore.instance.collection('notes').doc();
                newDeckRef.set({
                  'title': 'Új köteg',
                  'type': 'deck',
                  'card_ids': [],
                  'modified': Timestamp.now(),
                }).then((_) {
                  context.go('/decks/edit/${newDeckRef.id}');
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Új Köteg'),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'decks'),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notes')
                  .where('type', isEqualTo: 'deck')
                  .orderBy('modified', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.style),
                      title: Text(data['title'] ?? 'Névtelen köteg'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => context.go('/decks/edit/${doc.id}'),
                      ),
                      onTap: () => context.go('/decks/view/${doc.id}'),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';

class QuestionBankListScreen extends StatefulWidget {
  const QuestionBankListScreen({super.key});

  @override
  State<QuestionBankListScreen> createState() => _QuestionBankListScreenState();
}

class _QuestionBankListScreenState extends State<QuestionBankListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kérdésbankok'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                final router = GoRouter.of(context);
                final newBankRef = FirebaseFirestore.instance
                    .collection('question_banks')
                    .doc();
                await newBankRef.set({
                  'name': 'Új kérdésbank',
                  'createdAt': Timestamp.now(),
                  'questions': [],
                });
                if (mounted) {
                  router.go('/question-banks/edit/${newBankRef.id}');
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Új Kérdésbank'),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'question_banks'),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('question_banks')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final questions = data['questions'] as List<dynamic>? ?? [];
                    return ListTile(
                      leading: const Icon(Icons.quiz),
                      title: Text(data['name'] ?? 'Névtelen kérdésbank'),
                      subtitle: Text('${questions.length} kérdés'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Szerkesztés',
                            onPressed: () =>
                                context.go('/question-banks/edit/${doc.id}'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            tooltip: 'Törlés',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Kérdésbank törlése'),
                                  content: Text(
                                      'Biztosan törölni szeretnéd a(z) "${data['name'] ?? 'Névtelen'}" kérdésbankot? A művelet nem visszavonható.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Mégse')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        style: TextButton.styleFrom(
                                            foregroundColor: Colors.red),
                                        child: const Text('Törlés')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await doc.reference.delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Kérdésbank törölve.')));
                                }
                              }
                            },
                          ),
                        ],
                      ),
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

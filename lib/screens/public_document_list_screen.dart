import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:orlomed_admin_web/core/firebase_config.dart';
import 'package:orlomed_admin_web/widgets/sidebar.dart';

class PublicDocumentListScreen extends StatefulWidget {
  const PublicDocumentListScreen({super.key});

  @override
  State<PublicDocumentListScreen> createState() =>
      _PublicDocumentListScreenState();
}

class _PublicDocumentListScreenState extends State<PublicDocumentListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 250, 251),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'public_documents'),
          Expanded(
            child: Column(
              children: [
                // Header-t itt nem használjuk, mert nincs keresés
                AppBar(
                  title: const Text('Nyilvános Dokumentumok'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 20.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Új Dokumentum'),
                        onPressed: () {
                          context.go('/public-documents/create');
                        },
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseConfig.publicFirestore
                        .collection('public_documents')
                        .orderBy('category')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Hiba: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('Nincsenek dokumentumok.'));
                      }

                      final documents = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          final doc = documents[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final title = data['title'] ?? 'Nincs cím';
                          final category =
                              data['category'] ?? 'Nincs kategória';
                          final language = data['language'] ?? 'hu';
                          final languageFlag =
                              language == 'en' ? '🇬🇧' : '🇭🇺';
                          final version = data['version'] ?? '-';
                          final modified =
                              (data['publishedAt'] as Timestamp?)?.toDate();

                          return ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: Text('$title $languageFlag'),
                            subtitle: Text(
                                'Kategória: $category | Nyelv: $language | Verzió: $version'),
                            trailing: Text(modified != null
                                ? '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}'
                                : 'Ismeretlen dátum'),
                            onTap: () {
                              context.go('/public-documents/edit/${doc.id}');
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

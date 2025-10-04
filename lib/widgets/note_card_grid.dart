import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/firebase_config.dart';
import 'note_list_tile.dart';

class NoteCardGrid extends StatelessWidget {
  final String searchText;
  final String? selectedStatus;
  final String? selectedCategory;
  final String? selectedScience;
  final String? selectedTag;
  final String? selectedType;

  const NoteCardGrid({
    super.key,
    required this.searchText,
    this.selectedStatus,
    this.selectedCategory,
    this.selectedScience,
    this.selectedTag,
    this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
        FirebaseConfig.firestore.collection('notes');

    if (selectedStatus != null && selectedStatus!.isNotEmpty) {
      query = query.where('status', isEqualTo: selectedStatus);
    }
    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      query = query.where('category', isEqualTo: selectedCategory);
    }
    if (selectedScience != null && selectedScience!.isNotEmpty) {
      query = query.where('science', isEqualTo: selectedScience);
    }
    if (selectedTag != null && selectedTag!.isNotEmpty) {
      query = query.where('tags', arrayContains: selectedTag);
    }
    if (selectedType != null && selectedType!.isNotEmpty) {
      query = query.where('type', isEqualTo: selectedType);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Hiba az adatok betöltésekor.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs
            .where((d) => !(d.data()['deletedAt'] != null))
            .where((d) => (d.data()['title'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchText.toLowerCase()))
            .toList();

        if (docs.isEmpty) {
          return const Center(child: Text('Nincs találat.'));
        }

        // Csoportosítás kategóriánként
        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            grouped = {};
        for (var d in docs) {
          final cat = (d.data()['category'] ?? 'Egyéb') as String;
          grouped.putIfAbsent(cat, () => []).add(d);
        }

        // Kategórián belüli rendezés típus és cím alapján
        grouped.forEach((key, value) {
          value.sort((a, b) {
            final typeA = a.data()['type'] as String? ?? '';
            final typeB = b.data()['type'] as String? ?? '';
            final typeCompare = typeA.compareTo(typeB);
            if (typeCompare != 0) {
              return typeCompare;
            }
            final titleA = a.data()['title'] as String? ?? '';
            final titleB = b.data()['title'] as String? ?? '';
            return titleA.compareTo(titleB);
          });
        });

        return ListView(
          padding: EdgeInsets.zero,
          children: grouped.entries.map((entry) {
            final items = entry.value;
            return _CategorySection(category: entry.key, docs: items);
          }).toList(),
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _CategorySection({required this.category, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              category,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final type = data['type'] as String? ?? 'standard';
              return NoteListTile(
                id: doc.id,
                title: data['title'] ?? '',
                type: type,
                hasDoc: (data['docxUrl'] ?? '').toString().isNotEmpty,
                hasAudio: (data['audioUrl'] ?? '').toString().isNotEmpty,
                audioUrl: (data['audioUrl'] ?? '').toString(),
                hasVideo: (data['videoUrl'] ?? '').toString().isNotEmpty,
                deckCount: type == 'deck'
                    ? (data['flashcards'] as List<dynamic>? ?? []).length
                    : null,
              );
            },
          )
        ],
      ),
    );
  }
}

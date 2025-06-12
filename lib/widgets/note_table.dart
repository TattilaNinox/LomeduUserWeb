import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import 'video_preview_player.dart';
import 'mini_audio_player.dart';

class NoteTable extends StatelessWidget {
  final String searchText;
  final String? selectedStatus;
  final String? selectedCategory;
  final String? selectedTag;

  const NoteTable({
    super.key,
    required this.searchText,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.selectedTag,
  });

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('notes');

    if (selectedStatus != null && selectedStatus!.isNotEmpty) {
      query = query.where('status', isEqualTo: selectedStatus);
    }
    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      query = query.where('category', isEqualTo: selectedCategory);
    }
    if (selectedTag != null && selectedTag!.isNotEmpty) {
      query = query.where('tags', arrayContains: selectedTag);
    }

    return Expanded(
      child: SingleChildScrollView(
        child: StreamBuilder<QuerySnapshot>(
          key: ValueKey('$selectedStatus|$selectedCategory|$selectedTag|$searchText'),
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Hiba történt az adatok betöltésekor.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('Nincsenek jegyzetek.'));
            }

            final notes = snapshot.data!.docs;
            if (notes.isEmpty) {
              return const Center(child: Text('Nincsenek találatok.'));
            }

            final filteredNotes = notes.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = (data['title'] ?? '') as String;
              return title.toLowerCase().contains(searchText.toLowerCase());
            }).toList();

            if (filteredNotes.isEmpty) {
              return const Center(child: Text('Nincsenek találatok.'));
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 40,
                columns: const [
                  DataColumn(label: Text('Cím')),
                  DataColumn(label: Text('Kategória')),
                  DataColumn(label: Text('Címkék')),
                  DataColumn(label: Text('Státusz')),
                  DataColumn(label: Text('Módosítva')),
                  DataColumn(label: Text('Fájlok')),
                  DataColumn(label: Text('Műveletek')),
                ],
                rows: filteredNotes.map((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final title = (data['title'] ?? '') as String;
                  final category = (data['category'] ?? '') as String;
                  final status = (data['status'] ?? '') as String;
                  final modified = (data['modified'] is Timestamp)
                      ? (data['modified'] as Timestamp).toDate()
                      : DateTime.now();
                  final hasDocx = data['docxUrl'] != null &&
                      data['docxUrl'].toString().isNotEmpty;
                  final hasAudio = data['audioUrl'] != null &&
                      data['audioUrl'].toString().isNotEmpty;
                  final hasVideo = data['videoUrl'] != null &&
                      data['videoUrl'].toString().isNotEmpty;
                  final noteType = data['type'] as String? ?? 'standard';

                  final tags = (data['tags'] as List<dynamic>? ?? []).cast<String>();

                  const TextStyle cellStyle = TextStyle(fontSize: 12);

                  return DataRow(cells: [
                    DataCell(Text(title, style: cellStyle)),
                    DataCell(Text(category, style: cellStyle)),
                    DataCell(Row(
                      children: [
                        for (int i = 0; i < tags.length; i++) ...[
                          Text(tags[i],
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E90FF))),
                          if (i != tags.length - 1)
                            const SizedBox(width: 12),
                        ]
                      ],
                    )),
                    DataCell(Text(status, style: cellStyle)),
                    DataCell(Text(
                        '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}',
                        style: cellStyle)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasDocx)
                          Tooltip(
                            message: 'Dokumentum',
                            child: IconButton(
                              icon: const Icon(Icons.description,
                                  color: Colors.blue),
                              onPressed: () {
                                final googleDocsUrl =
                                    'https://docs.google.com/viewer?url=${Uri.encodeComponent(data['docxUrl'])}&embedded=true';
                                launchUrl(Uri.parse(googleDocsUrl));
                              },
                            ),
                          ),
                        if (hasAudio) MiniAudioPlayer(audioUrl: data['audioUrl']),
                        if (hasVideo)
                          Tooltip(
                            message: 'Videó',
                            child: IconButton(
                              icon: const Icon(Icons.movie,
                                  color: Colors.deepOrange),
                              onPressed: () =>
                                  _showVideoDialog(context, data['videoUrl']),
                            ),
                          ),
                      ],
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIconButton(
                            context,
                            Icons.visibility,
                            AppTheme.primaryColor,
                            () {
                              if (noteType == 'interactive') {
                                context.go('/interactive-note/${doc.id}');
                              } else {
                                context.go('/note/${doc.id}');
                              }
                            }),
                        _buildIconButton(
                            context,
                            Icons.edit,
                            AppTheme.primaryColor,
                            () => context.go('/note/edit/${doc.id}')),
                        _buildIconButton(
                            context,
                            Icons.publish,
                            AppTheme.successColor,
                            () => _publishNote(context, doc.id)),
                        _buildIconButton(
                            context,
                            Icons.delete_forever,
                            Colors.black,
                            () => _showDeleteAllDialog(context, doc.id)),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, IconData icon, Color color,
      VoidCallback onPressed) {
    String tooltip = '';
    switch (icon) {
      case Icons.edit:
        tooltip = 'Szerkesztés';
        break;
      case Icons.delete:
        tooltip = 'Törlés';
        break;
      case Icons.publish:
        tooltip = 'Publikálás';
        break;
      case Icons.visibility:
        tooltip = 'Előnézet';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Megerősítés',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: const Text(
            'Biztosan törlöd ezt a jegyzetet és minden hozzá tartozó fájlt?',
            style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nem',
                style:
                    TextStyle(color: Color(0xFF6B7280), fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              // 1. Storage-ból törlés (mappa)
              final folderRef = FirebaseStorage.instance.ref('notes/$docId');
              try {
                final listResult = await folderRef.listAll();
                for (final item in listResult.items) {
                  try {
                    await item.delete();
                  } catch (e) {
                    debugPrint('Fájl törlés hiba: $e');
                  }
                }
              } catch (e) {
                debugPrint('Mappa listázás hiba: $e');
              }

              // 2. Firestore dokumentum törlése
              try {
                await FirebaseFirestore.instance
                    .collection('notes')
                    .doc(docId)
                    .delete();
              } catch (e) {
                debugPrint('Firestore törlés hiba: $e');
              }

              if (!context.mounted) return;
              Navigator.of(context).pop();
              _showSnackBar(context, 'Jegyzet és minden fájl törölve.');
            },
            child: const Text('Igen',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }

  void _publishNote(BuildContext context, String docId) {
    FirebaseFirestore.instance.collection('notes').doc(docId).update({
      'status': 'Published',
      'modified': Timestamp.now(),
    }).then((_) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Jegyzet publikálva.');
    }).catchError((error) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Hiba történt a publikálás során.');
    });
  }

  void _showVideoDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Videó előnézet'),
        content: AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPreviewPlayer(videoUrl: videoUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bezárás'),
          ),
        ],
      ),
    );
  }
}

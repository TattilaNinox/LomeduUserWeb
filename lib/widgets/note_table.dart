import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import 'video_preview_player.dart';
import 'mini_audio_player.dart';
import 'quiz_viewer.dart';

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
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          final notes = snapshot.data!.docs
              .where((d) => !(d.data()!['deletedAt'] != null))
              .toList();
          if (notes.isEmpty) {
            return const Center(child: Text('Nincsenek találatok.'));
          }
          final filteredNotes = notes.where((doc) {
            final data = doc.data();
            final title = (data['title'] ?? '');
            return title.toLowerCase().contains(searchText.toLowerCase());
          }).toList();

          if (filteredNotes.isEmpty) {
            return const Center(child: Text('Nincsenek találatok.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              Widget buildTable({required bool shrink}) {
                return Column(
                  children: [
                    _buildHeader(),
                    shrink
                        ? ListView.builder(
                            itemCount: filteredNotes.length,
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final doc = filteredNotes[index];
                              final data = doc.data()!;
                              final noteType = data['type'] as String? ?? 'standard';
                              if (noteType == 'deck') {
                                return _buildDeckCard(context, doc);
                              } else {
                                return _buildNoteRow(context, doc);
                              }
                            },
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: filteredNotes.length,
                              itemBuilder: (context, index) {
                                final doc = filteredNotes[index];
                                final data = doc.data()!;
                                final noteType = data['type'] as String? ?? 'standard';
                                if (noteType == 'deck') {
                                  return _buildDeckCard(context, doc);
                                } else {
                                  return _buildNoteRow(context, doc);
                                }
                              },
                            ),
                          ),
                  ],
                );
              }

              final tableWide = buildTable(shrink: false);
              final tableNarrow = buildTable(shrink: true);

              // Ha keskeny a viewport, csomagoljuk vízszintes scrollba.
              const minW = 800.0;
              if (constraints.maxWidth < minW) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: minW, child: tableNarrow),
                );
              }

              return tableWide;
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    const TextStyle headerStyle =
        TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
        color: Color.fromARGB(255, 244, 245, 247),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Cím', style: headerStyle)),
          Expanded(flex: 2, child: Text('Kategória', style: headerStyle)),
          Expanded(flex: 2, child: Text('Címkék', style: headerStyle)),
          Expanded(flex: 1, child: Text('Státusz', style: headerStyle)),
          Expanded(flex: 1, child: Text('Módosítva', style: headerStyle)),
          Expanded(flex: 2, child: Text('Fájlok', style: headerStyle)),
          Expanded(flex: 2, child: Text('Műveletek', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildNoteRow(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final title = (data['title'] ?? '');
    final category = (data['category'] ?? '');
    final status = (data['status'] ?? '');
    final displayStatus = status == 'Public' ? 'Published' : status;
    final modified = (data['modified'] is Timestamp)
        ? (data['modified'] as Timestamp).toDate()
        : DateTime.now();
    final hasDocx =
        data['docxUrl'] != null && data['docxUrl'].toString().isNotEmpty;
    final hasAudio =
        data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty;
    final hasVideo =
        data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty;
    final noteType = data['type'] as String? ?? 'standard';
    final tags = (data['tags'] as List<dynamic>? ?? []).cast<String>();
    const TextStyle cellStyle = TextStyle(fontSize: 12);

    IconData getIconForNoteType(String type) {
      switch (type) {
        case 'deck':
          return Icons.style;
        case 'interactive':
          return Icons.touch_app;
        case 'dynamic_quiz':
          return Icons.quiz;
        default:
          return Icons.notes;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(getIconForNoteType(noteType), color: AppTheme.primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: cellStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              category,
              style: cellStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                for (int i = 0; i < tags.length; i++) ...[
                  Text(tags[i],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E90FF))),
                  if (i != tags.length - 1) const SizedBox(width: 12),
                ]
              ],
            ),
          ),
          Expanded(flex: 1, child: Text(displayStatus, style: cellStyle)),
          Expanded(
            flex: 1,
            child: Text(
                '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}',
                style: cellStyle),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasDocx)
                  Tooltip(
                    message: 'Dokumentum',
                    child: IconButton(
                      icon: const Icon(Icons.description, color: Colors.blue),
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
                      icon: const Icon(Icons.movie, color: Colors.deepOrange),
                      onPressed: () =>
                          _showVideoDialog(context, data['videoUrl']),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconButton(context, Icons.visibility,
                      AppTheme.primaryColor, () {
                    if (noteType == 'dynamic_quiz') {
                      final questionBankId = data['questionBankId'] as String?;
                      if (questionBankId != null) {
                        _showQuizPreviewDialog(context, questionBankId);
                      }
                    } else if (noteType == 'interactive') {
                      context.go('/interactive-note/${doc.id}');
                    } else {
                      context.go('/note/${doc.id}');
                    }
                  }),
                  _buildIconButton(context, Icons.edit, AppTheme.primaryColor,
                      () {
                    if (noteType == 'dynamic_quiz') {
                      context.go('/quiz/edit/${doc.id}');
                    } else {
                      context.go('/note/edit/${doc.id}');
                    }
                  }),
                  _buildStatusMenu(context, doc.id, status),
                  _buildIconButton(context, Icons.delete_forever, Colors.black,
                      () => _showDeleteAllDialog(context, doc.id)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckCard(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final title = data['title'] as String? ?? 'Névtelen pakli';
    final flashcards = data['flashcards'] as List<dynamic>? ?? [];
    final category = (data['category'] ?? '');
    final status = (data['status'] ?? '');
    final displayStatus = status == 'Public' ? 'Published' : status;
    final modified = (data['modified'] is Timestamp)
        ? (data['modified'] as Timestamp).toDate()
        : DateTime.now();
    final hasDocx =
        data['docxUrl'] != null && data['docxUrl'].toString().isNotEmpty;
    final hasAudio =
        data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty;
    final hasVideo =
        data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty;
    final noteType = data['type'] as String? ?? 'standard';
    final tags = (data['tags'] as List<dynamic>? ?? []).cast<String>();
    const TextStyle cellStyle = TextStyle(fontSize: 12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.style, color: AppTheme.primaryColor),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false),
                    if (flashcards.isNotEmpty)
                      Text('${flashcards.length} kártya',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              category,
              style: cellStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                for (int i = 0; i < tags.length; i++) ...[
                  Text(tags[i],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E90FF))),
                  if (i != tags.length - 1) const SizedBox(width: 12),
                ]
              ],
            ),
          ),
          Expanded(flex: 1, child: Text(displayStatus, style: cellStyle)),
          Expanded(
            flex: 1,
            child: Text(
              '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}',
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasDocx)
                  Tooltip(
                    message: 'Dokumentum',
                    child: IconButton(
                      icon: const Icon(Icons.description, color: Colors.blue),
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
                      icon: const Icon(Icons.movie, color: Colors.deepOrange),
                      onPressed: () =>
                          _showVideoDialog(context, data['videoUrl']),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconButton(context, Icons.visibility, AppTheme.primaryColor,
                      () {
                    context.go('/deck/${doc.id}/view');
                  }),
                  _buildIconButton(context, Icons.edit, AppTheme.primaryColor, () {
                    context.go('/decks/edit/${doc.id}');
                  }),
                  _buildStatusMenu(context, doc.id, status),
                  _buildIconButton(context, Icons.delete_forever, Colors.black,
                      () => _showDeleteAllDialog(context, doc.id)),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildStatusMenu(BuildContext context, String noteId, String currentStatus) {
    const statuses = ['Published', 'Draft', 'Archived'];
    final effectiveStatus = currentStatus == 'Public' ? 'Published' : currentStatus;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppTheme.primaryColor),
      tooltip: 'Státusz módosítása',
      onSelected: (String newStatus) {
        _updateNoteStatus(context, noteId, newStatus);
      },
      itemBuilder: (BuildContext context) {
        return statuses.map((String status) {
          return PopupMenuItem<String>(
            value: status,
            child: Text(status, style: TextStyle(
              color: status == effectiveStatus ? Colors.blue : null,
              fontWeight: status == effectiveStatus ? FontWeight.bold : FontWeight.normal,
            )),
          );
        }).toList();
      },
    );
  }

  Future<void> _updateNoteStatus(BuildContext context, String noteId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('notes').doc(noteId).update({
        'status': newStatus,
        'modified': Timestamp.now(),
      });
      if (!context.mounted) return;
      _showSnackBar(context, 'Státusz sikeresen frissítve!');
    } catch (e) {
      _showSnackBar(context, 'Hiba a státusz frissítésekor: $e');
    }
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
              Navigator.of(context).pop();

              // Soft delete: csak deletedAt-et állítunk.
              await FirebaseFirestore.instance
                  .collection('notes')
                  .doc(docId)
                  .update({'deletedAt': Timestamp.now()});

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Jegyzet törölve'),
                  action: SnackBarAction(
                    label: 'VISSZAVONÁS',
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('notes')
                          .doc(docId)
                          .update({'deletedAt': FieldValue.delete()});
                    },
                  ),
                  duration: const Duration(seconds: 8),
                ),
              );
            },
            child: const Text('Igen, törlés', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }

  void _showVideoDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.7,
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

  void _showQuizPreviewDialog(BuildContext context, String bankId) async {
    final bankDoc = await FirebaseFirestore.instance.collection('question_banks').doc(bankId).get();
    if (!bankDoc.exists) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hiba: A kérdésbank nem található.')));
      return;
    }
    final bank = bankDoc.data()!;
    final questions = List<Map<String, dynamic>>.from(bank['questions'] ?? []);
    questions.shuffle();
    final selectedQuestions = questions.take(10).toList();

    if (selectedQuestions.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ez a kérdésbank nem tartalmaz kérdéseket.')));
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: const EdgeInsets.all(8),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: QuizViewer(questions: selectedQuestions),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bezárás'),
            )
          ],
        ),
      );
    }
  }
}
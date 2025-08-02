import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'video_preview_player.dart';
import 'mini_audio_player.dart';
import 'quiz_viewer.dart';
import 'quiz_viewer_dual.dart';

enum SortColumn { title, category, tags, status, modified }

class NoteTable extends StatefulWidget {
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

  @override
  State<NoteTable> createState() => _NoteTableState();
}

class _NoteTableState extends State<NoteTable> {
  SortColumn _sortColumn = SortColumn.modified;
  bool _ascending = false;

  void _toggleSort(SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        // Alapértelmezett irány: szövegesnél növekvő, dátumnál csökkenő
        _ascending = column == SortColumn.modified ? false : true;
      }
    });
  }

  int _compareDocs(DocumentSnapshot a, DocumentSnapshot b) {
    final ad = a.data() as Map<String, dynamic>;
    final bd = b.data() as Map<String, dynamic>;
    int cmp;
    switch (_sortColumn) {
      case SortColumn.title:
        cmp = _str(ad['title']).compareTo(_str(bd['title']));
        break;
      case SortColumn.category:
        cmp = _str(ad['category']).compareTo(_str(bd['category']));
        break;
      case SortColumn.tags:
        cmp = _str((ad['tags'] ?? []).join(','))
            .compareTo(_str((bd['tags'] ?? []).join(',')));
        break;
      case SortColumn.status:
        cmp = _str(ad['status']).compareTo(_str(bd['status']));
        break;
      case SortColumn.modified:
        cmp = _date(ad['modified']).compareTo(_date(bd['modified']));
        break;
    }
    return _ascending ? cmp : -cmp;
  }

  String _str(Object? v) => (v ?? '').toString().toLowerCase();

  DateTime _date(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('notes');

    if (widget.selectedStatus != null && widget.selectedStatus!.isNotEmpty) {
      query = query.where('status', isEqualTo: widget.selectedStatus);
    }
    if (widget.selectedCategory != null && widget.selectedCategory!.isNotEmpty) {
      query = query.where('category', isEqualTo: widget.selectedCategory);
    }
    if (widget.selectedTag != null && widget.selectedTag!.isNotEmpty) {
      query = query.where('tags', arrayContains: widget.selectedTag);
    }

    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey('$widget.selectedStatus|$widget.selectedCategory|$widget.selectedTag|$widget.searchText'),
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
              .where((d) => !(d.data()['deletedAt'] != null))
              .toList();
          if (notes.isEmpty) {
            return const Center(child: Text('Nincsenek találatok.'));
          }
          final filteredNotes = notes.where((doc) {
            final data = doc.data()  ;
            final title = (data['title'] ?? '');
            return title.toLowerCase().contains(widget.searchText.toLowerCase());
          }).toList();

          if (filteredNotes.isEmpty) {
            return const Center(child: Text('Nincsenek találatok.'));
          }

          // Rendezés a kiválasztott oszlop szerint
          filteredNotes.sort(_compareDocs);

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
                              final data = doc.data();
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
                                final data = doc.data();
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
    const TextStyle headerStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);

    Widget buildCell(String label, SortColumn column, int flex) {
      final bool isActive = _sortColumn == column;
      final icon = isActive
          ? (_ascending ? Icons.arrow_upward : Icons.arrow_downward)
          : null;
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => _toggleSort(column),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: headerStyle),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 14, color: Colors.black54),
              ]
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
        color: Color.fromARGB(255, 244, 245, 247),
      ),
      child: Row(
        children: [
          buildCell('Cím', SortColumn.title, 3),
          buildCell('Kategória', SortColumn.category, 2),
          buildCell('Címkék', SortColumn.tags, 2),
          buildCell('Státusz', SortColumn.status, 1),
          buildCell('Módosítva', SortColumn.modified, 1),
          const Expanded(flex: 2, child: Text('Fájlok', style: headerStyle)),
          const Expanded(flex: 2, child: Text('Műveletek', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildNoteRow(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
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
        case 'dynamic_quiz_dual':
          return Icons.quiz_outlined;
        default:
          return Icons.menu_book;
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
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    data['isFree'] == true ? Icons.lock_open : Icons.lock,
                    color: data['isFree'] == true ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: data['isFree'] == true ? 'Ingyenes jegyzet' : 'Fizetős jegyzet',
                  onPressed: () => _toggleFreeStatus(context, doc.id, data['isFree'] == true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: cellStyle.copyWith(color: noteType == 'source' ? const Color(0xFF009B77) : null),
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
                    if (noteType == 'dynamic_quiz' || noteType == 'dynamic_quiz_dual') {
                      final questionBankId = data['questionBankId'] as String?;
                      if (questionBankId != null) {
                        _showQuizPreviewDialog(context, questionBankId, dualMode: noteType == 'dynamic_quiz_dual');
                      }
                    } else if (noteType == 'interactive') {
                      context.go('/interactive-note/${doc.id}');
                    } else if (noteType == 'source') {
                      context.go('/references');
                    } else {
                      context.go('/note/${doc.id}');
                    }
                  }),
                  _buildIconButton(context, Icons.edit, AppTheme.primaryColor,
                      () {
                    if (noteType == 'dynamic_quiz' || noteType == 'dynamic_quiz_dual') {
                      context.go(noteType == 'dynamic_quiz' ? '/quiz/edit/${doc.id}' : '/quiz-dual/edit/${doc.id}');
                    } else if (noteType == 'source') {
                      context.go('/sources-admin?edit=${doc.id}');
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
    final data = doc.data() ?? <String, dynamic>{};
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
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    data['isFree'] == true ? Icons.lock_open : Icons.lock,
                    color: data['isFree'] == true ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: data['isFree'] == true ? 'Ingyenes jegyzet' : 'Fizetős jegyzet',
                  onPressed: () => _toggleFreeStatus(context, doc.id, data['isFree'] == true),
                ),
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

  Future<void> _toggleFreeStatus(BuildContext context, String noteId, bool currentFree) async {
    try {
      await FirebaseFirestore.instance.collection('notes').doc(noteId).update({
        'isFree': !currentFree,
        'modified': Timestamp.now(),
      });
      if (!context.mounted) return;
      _showSnackBar(context, !currentFree ? 'A jegyzet mostantól ingyenes!' : 'Ingyenes státusz kikapcsolva');
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

              try {
                // Hard delete: teljes dokumentum törlése.
                await FirebaseFirestore.instance
                    .collection('notes')
                    .doc(docId)
                    .delete();

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Jegyzet véglegesen törölve')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hiba a törlés során: $e')),
                );
              }
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

  void _showQuizPreviewDialog(BuildContext context, String bankId, {bool dualMode = false}) async {
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
            child: dualMode ? QuizViewerDual(questions: selectedQuestions) : QuizViewer(questions: selectedQuestions),
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
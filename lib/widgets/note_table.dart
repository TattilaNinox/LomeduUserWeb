import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import 'video_preview_player.dart';
import 'mini_audio_player.dart';
import 'quiz_viewer.dart';

/// A jegyzeteket táblázatos formában megjelenítő, szűrhető és kereshető widget.
///
/// Ez egy `StatelessWidget`, mivel a szűrési és keresési feltételeket a
/// szülő widgettől (`NoteListScreen`) kapja meg. A widget fő feladata, hogy
/// a kapott feltételek alapján összeállítson és végrehajtson egy Firestore
/// lekérdezést, majd az eredményt egy `StreamBuilder` segítségével, valós időben
/// megjelenítse egy `DataTable`-ben.
class NoteTable extends StatelessWidget {
  // A szülőtől kapott keresési és szűrési paraméterek.
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

  /// Egy segédfüggvény, ami egy `SnackBar`-t (felugró értesítési sávot) jelenít meg.
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A Firestore lekérdezés dinamikus felépítése.
    // A `notes` kollekcióval kezdjük, majd a feltételek alapján láncoljuk
    // a `.where()` hívásokat.
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('notes');

    // Ha van státusz szűrő, hozzáadjuk a lekérdezéshez.
    if (selectedStatus != null && selectedStatus!.isNotEmpty) {
      query = query.where('status', isEqualTo: selectedStatus);
    }
    // Ha van kategória szűrő, hozzáadjuk a lekérdezéshez.
    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      query = query.where('category', isEqualTo: selectedCategory);
    }
    // Ha van címke szűrő, egy `array-contains` lekérdezéssel adjuk hozzá.
    // Ez ellenőrzi, hogy a `tags` tömb tartalmazza-e a kiválasztott címkét.
    if (selectedTag != null && selectedTag!.isNotEmpty) {
      query = query.where('tags', arrayContains: selectedTag);
    }

    // Az `Expanded` biztosítja, hogy a táblázat kitöltse a rendelkezésre álló
    // függőleges teret a `NoteListScreen`-en belül.
    return Expanded(
      child: SingleChildScrollView(
        // A `StreamBuilder` a modern Flutter alkalmazások egyik kulcsfontosságú eleme.
        // Feliratkozik egy `Stream`-re (ebben az esetben a Firestore lekérdezés
        // változásaira), és minden új adat érkezésekor újraépíti a `builder`
        // által visszaadott widget-fát.
        child: StreamBuilder<QuerySnapshot>(
          // A `key` segít a Flutternek megkülönböztetni a `StreamBuilder`
          // példányokat, ha a szűrők változnak. Ez biztosítja, hogy új
          // lekérdezés esetén a `StreamBuilder` újraépüljön és ne a régi
          // adatokat mutassa.
          key: ValueKey('$selectedStatus|$selectedCategory|$selectedTag|$searchText'),
          stream: query.snapshots(),
          builder: (context, snapshot) {
            // Hibakezelés a stream-ben.
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Hiba történt az adatok betöltésekor.'));
            }
            // Amíg az adatok töltődnek, vagy ha nincs adat.
            if (!snapshot.hasData) {
              return const Center(child: Text('Nincsenek jegyzetek.'));
            }

            final notes = snapshot.data!.docs;
            // Ha a Firestore lekérdezés üres eredménnyel tér vissza.
            if (notes.isEmpty) {
              return const Center(child: Text('Nincsenek találatok.'));
            }

            // Kliens oldali keresés a jegyzetek címében.
            // A Firestore nem támogatja a natív "contains" keresést a szöveges
            // mezőkön, ezért a szűrt eredményeket tovább szűrjük a kliens oldalon.
            final filteredNotes = notes.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = (data['title'] ?? '') as String;
              return title.toLowerCase().contains(searchText.toLowerCase());
            }).toList();

            if (filteredNotes.isEmpty) {
              return const Center(child: Text('Nincsenek találatok.'));
            }

            // A `SingleChildScrollView` biztosítja a vízszintes görgetést,
            // ha a táblázat nem fér el a képernyőn.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // A `DataTable` widget a jegyzetek táblázatos megjelenítéséért felelős.
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
                // A `rows` tulajdonság a `filteredNotes` listából generálja
                // a táblázat sorait a `.map()` függvénnyel.
              rows: filteredNotes.map((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final title = (data['title'] ?? '') as String;
                final category = (data['category'] ?? '') as String;
                final status = (data['status'] ?? '') as String;
                  final displayStatus = status == 'Public' ? 'Published' : status;
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

                  // Minden egyes jegyzet egy `DataRow`-t kap a táblázatban.
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
                    DataCell(Text(displayStatus, style: cellStyle)),
                  DataCell(Text(
                        '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}',
                        style: cellStyle)),
                    // Fájl ikonok cellája. Az ikonok feltételesen jelennek meg,
                    // attól függően, hogy a jegyzethez tartozik-e adott típusú fájl.
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
                                // A DOCX fájlokat a Google Docs Viewer segítségével
                                // nyitja meg egy új böngészőfülön.
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
                    // Művelet gombok cellája.
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Előnézet gomb, ami a jegyzet típusa alapján
                        // a megfelelő megtekintő képernyőre navigál.
                        _buildIconButton(
                            context,
                            Icons.visibility,
                            AppTheme.primaryColor,
                            () {
                              if (noteType == 'dynamic_quiz') {
                                final questionBankId = data['questionBankId'] as String?;
                                if (questionBankId != null) {
                                  // Ideiglenesen egy dialógusban jelenítjük meg a kvízt
                                  _showQuizPreviewDialog(context, questionBankId);
                                }
                              } else if (noteType == 'interactive') {
                                context.go('/interactive-note/${doc.id}');
                              } else {
                                context.go('/note/${doc.id}');
                              }
                            }),
                        // Szerkesztés gomb.
                        _buildIconButton(
                            context,
                            Icons.edit,
                            AppTheme.primaryColor,
                            () {
                              if (noteType == 'dynamic_quiz') {
                                context.go('/quiz/edit/${doc.id}');
                              } else {
                                context.go('/note/edit/${doc.id}');
                              }
                            }),
                        // Státuszváltó menü
                        _buildStatusMenu(context, doc.id, status),
                        // Törlés gomb.
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

  /// Egy segédfüggvény, ami egy `IconButton`-t hoz létre `Tooltip`-pel.
  /// A `Tooltip` megjeleníti a gomb funkcióját, ha a felhasználó
  /// az egeret a gomb fölé viszi.
  Widget _buildIconButton(BuildContext context, IconData icon, Color color,
      VoidCallback onPressed) {
    String tooltip = '';
    // Az ikon alapján meghatározza a tooltip szövegét.
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
      _showSnackBar(context, 'Státusz sikeresen frissítve!');
    } catch (e) {
      _showSnackBar(context, 'Hiba a státusz frissítésekor: $e');
    }
  }

  /// Megjelenít egy megerősítő párbeszédablakot a jegyzet és a hozzá
  /// tartozó fájlok törlése előtt.
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
          // "Nem" gomb, ami bezárja a párbeszédablakot.
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nem',
                style:
                    TextStyle(color: Color(0xFF6B7280), fontFamily: 'Inter')),
          ),
          // "Igen" gomb, ami elindítja a törlési folyamatot.
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              // 1. Törlés a Firebase Storage-ból (a jegyzethez tartozó mappa)
              final folderRef = FirebaseStorage.instance.ref('notes/$docId');
              try {
                // Lekéri a mappában lévő összes fájlt.
                final listResult = await folderRef.listAll();
                // Végigmegy a fájlokon és egyenként törli őket.
                for (final item in listResult.items) {
                  try {
                    await item.delete();
                  } catch (e) {
                    if (!context.mounted) return;
                    _showSnackBar(context, 'Hiba a fájl törlésekor: ${item.name}');
                  }
                }
              } catch (e) {
                if (!context.mounted) return;
                 _showSnackBar(context, 'Hiba a fájlok listázásakor: $e');
              }

              try {
                await FirebaseFirestore.instance.collection('notes').doc(docId).delete();
                if (!context.mounted) return;
                _showSnackBar(context, 'Jegyzet sikeresen törölve.');
              } catch (e) {
                if (!context.mounted) return;
                 _showSnackBar(context, 'Hiba a jegyzet törlésekor: $e');
              }

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Igen, törlés', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }

  /// Megjeleníti a videót egy `AlertDialog`-ban.
  void _showVideoDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // A `contentPadding` eltávolítása, hogy a videó kitöltse a rendelkezésre álló teret.
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.7,
          // A `VideoPreviewPlayer` egy egyedi widget, ami a videó lejátszását kezeli.
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
    // Itt újra le kell kérdezni a kérdéseket, mivel ez egy stateless widget
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

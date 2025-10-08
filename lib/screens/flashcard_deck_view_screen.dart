import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/sidebar.dart';
import '../widgets/learning_status_badge.dart';
import '../utils/filter_storage.dart';
import 'package:orlomed_admin_web/widgets/flippable_card.dart';

class FlashcardDeckViewScreen extends StatefulWidget {
  final String deckId;
  const FlashcardDeckViewScreen({super.key, required this.deckId});

  @override
  State<FlashcardDeckViewScreen> createState() =>
      _FlashcardDeckViewScreenState();
}

class _FlashcardDeckViewScreenState extends State<FlashcardDeckViewScreen> {
  DocumentSnapshot? _deckData;
  bool _isLoading = true;
  Map<int, Map<String, dynamic>> _learningData = {};

  @override
  void initState() {
    super.initState();
    _loadDeckData();
  }

  Future<void> _loadDeckData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('notes')
          .doc(widget.deckId)
          .get();
      
      if (mounted) {
        final data = doc.data();
        final categoryId = data?['category'] as String? ?? 'default';
        final flashcards = List<Map<String, dynamic>>.from(data?['flashcards'] ?? []);
        
        // Tanulási adatok betöltése
        Map<int, Map<String, dynamic>> learningData = {};
        if (flashcards.isNotEmpty) {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              // Batch lekérdezés a tanulási adatokhoz (10-es blokkokban)
              final allCardIds = List.generate(flashcards.length, (i) => '${widget.deckId}#$i');
              const chunkSize = 10;
              final learningDocs = <QueryDocumentSnapshot>[];
              
              for (var i = 0; i < allCardIds.length; i += chunkSize) {
                final chunk = allCardIds.sublist(i, (i + chunkSize).clamp(0, allCardIds.length));
                final query = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('categories')
                    .doc(categoryId)
                    .collection('learning')
                    .where(FieldPath.documentId, whereIn: chunk)
                    .get();
                learningDocs.addAll(query.docs);
              }
              
              final now = Timestamp.now();
              for (final doc in learningDocs) {
                final cardId = doc.id;
                final index = int.tryParse(cardId.split('#').last) ?? -1;
                if (index >= 0) {
                  final docData = doc.data() as Map<String, dynamic>?;
                  final state = docData?['state'] as String? ?? 'NEW';
                  final lastRating = docData?['lastRating'] as String? ?? 'Again';
                  final nextReview = docData?['nextReview'] as Timestamp?;
                  final isDue = state == 'NEW' || 
                               (nextReview != null && nextReview.seconds <= now.seconds);
                  
                  learningData[index] = {
                    'state': state,
                    'lastRating': lastRating,
                    'isDue': isDue,
                  };
                }
              }
            }
          } catch (e) {
            debugPrint('Error loading learning data: $e');
          }
        }
        
        setState(() {
          _deckData = doc;
          _learningData = learningData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hiba a pakli betöltése közben: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_deckData == null || !_deckData!.exists) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Hiba',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).primaryColor,
              size: isMobile ? 20 : 22,
            ),
            onPressed: () {
              // URL paraméterekkel vissza navigálás a szűrők megőrzéséhez
              final uri = Uri(
                path: '/notes',
                queryParameters: {
                  if (FilterStorage.searchText != null &&
                      FilterStorage.searchText!.isNotEmpty)
                    'q': FilterStorage.searchText!,
                  if (FilterStorage.status != null)
                    'status': FilterStorage.status!,
                  if (FilterStorage.category != null)
                    'category': FilterStorage.category!,
                  if (FilterStorage.science != null)
                    'science': FilterStorage.science!,
                  if (FilterStorage.tag != null) 'tag': FilterStorage.tag!,
                  if (FilterStorage.type != null) 'type': FilterStorage.type!,
                },
              );
              context.go(uri.toString());
            },
          ),
        ),
        body: const Center(child: Text('A pakli nem található.')),
      );
    }

    final data = _deckData!.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Névtelen pakli';
    final flashcards =
        List<Map<String, dynamic>>.from(data['flashcards'] ?? []);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 1200;

      final content = flashcards.isEmpty
          ? const Center(child: Text('Ez a pakli üres.'))
          : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: isWide
                      ? const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.6,
                        )
                      : const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                  itemCount: flashcards.length,
                  itemBuilder: (context, index) {
                    final learningInfo = _learningData[index];
                    return Stack(
                      children: [
                        FlippableCard(
                          frontText: flashcards[index]['front'] ?? '',
                          backText: flashcards[index]['back'] ?? '',
                        ),
                        if (learningInfo != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: LearningStatusBadge(
                              state: learningInfo['state'] as String,
                              lastRating: learningInfo['lastRating'] as String,
                              isDue: learningInfo['isDue'] as bool,
                            ),
                          ),
                      ],
                    );
                  },
                );

      if (isWide) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (flashcards.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(
                      Icons.school,
                      color: Color(0xFF1E3A8A), // Bíborkék
                    ),
                    tooltip: 'Tanulás',
                    onPressed: () {
                      context.go('/deck/${widget.deckId}/study');
                    },
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).primaryColor,
                size: isMobile ? 20 : 22,
              ),
              onPressed: () {
                // URL paraméterekkel vissza navigálás a szűrők megőrzéséhez
                final uri = Uri(
                  path: '/notes',
                  queryParameters: {
                    if (FilterStorage.searchText != null &&
                        FilterStorage.searchText!.isNotEmpty)
                      'q': FilterStorage.searchText!,
                    if (FilterStorage.status != null)
                      'status': FilterStorage.status!,
                    if (FilterStorage.category != null)
                      'category': FilterStorage.category!,
                    if (FilterStorage.science != null)
                      'science': FilterStorage.science!,
                    if (FilterStorage.tag != null) 'tag': FilterStorage.tag!,
                    if (FilterStorage.type != null) 'type': FilterStorage.type!,
                  },
                );
                context.go(uri.toString());
              },
            ),
          ),
          body: Row(
            children: [
              const Sidebar(selectedMenu: 'notes'),
              Expanded(child: content),
            ],
          ),
        );
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (flashcards.isNotEmpty) ...[
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(
                    Icons.school,
                    color: Color(0xFF1E3A8A), // Bíborkék
                  ),
                  tooltip: 'Tanulás',
                  onPressed: () {
                    context.go('/deck/${widget.deckId}/study');
                  },
                ),
              ],
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).primaryColor,
              size: isMobile ? 20 : 22,
            ),
            onPressed: () {
              // URL paraméterekkel vissza navigálás a szűrők megőrzéséhez
              final uri = Uri(
                path: '/notes',
                queryParameters: {
                  if (FilterStorage.searchText != null &&
                      FilterStorage.searchText!.isNotEmpty)
                    'q': FilterStorage.searchText!,
                  if (FilterStorage.status != null)
                    'status': FilterStorage.status!,
                  if (FilterStorage.category != null)
                    'category': FilterStorage.category!,
                  if (FilterStorage.science != null)
                    'science': FilterStorage.science!,
                  if (FilterStorage.tag != null) 'tag': FilterStorage.tag!,
                  if (FilterStorage.type != null) 'type': FilterStorage.type!,
                },
              );
              context.go(uri.toString());
            },
          ),
        ),
        drawer: const Drawer(
          child: SafeArea(
            child: Sidebar(selectedMenu: 'notes'),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: content,
        ),
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_html/flutter_html.dart';
import '../widgets/sidebar.dart';

class DeckViewScreen extends StatefulWidget {
  final String deckId;
  const DeckViewScreen({super.key, required this.deckId});

  @override
  State<DeckViewScreen> createState() => _DeckViewScreenState();
}

class _DeckViewScreenState extends State<DeckViewScreen> {
  DocumentSnapshot? _deck;
  List<DocumentSnapshot> _cards = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final deckDoc = await FirebaseFirestore.instance.collection('notes').doc(widget.deckId).get();
    if (!deckDoc.exists) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final data = deckDoc.data() as Map<String, dynamic>;
    final cardIds = List<String>.from(data['card_ids'] ?? []);
    
    if(cardIds.isNotEmpty) {
      final cardDocs = await FirebaseFirestore.instance.collection('notes').where(FieldPath.documentId, whereIn: cardIds).get();
      // Sorba rendezés a card_ids lista alapján
      _cards = cardDocs.docs..sort((a,b) => cardIds.indexOf(a.id).compareTo(cardIds.indexOf(b.id)));
    }
    
    if (mounted) {
      setState(() {
        _deck = deckDoc;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_deck == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('A köteg nem található.')));
    }
    
    final title = (_deck!.data() as Map<String, dynamic>)['title'] ?? 'Névtelen köteg';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'decks'),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _cards.isEmpty
                      ? const Center(child: Text('Nincsenek kártyák ebben a kötegben.'))
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: _cards.length,
                          onPageChanged: (index) => setState(() => _currentPage = index),
                          itemBuilder: (context, index) {
                            final cardData = _cards[index].data() as Map<String, dynamic>;
                            final htmlContent = cardData['html'] ?? 'Nincs tartalom.';
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SingleChildScrollView(child: Html(data: htmlContent)),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: _currentPage > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.ease,
                                );
                              }
                            : null,
                      ),
                      Text(
                        'Kártya ${_currentPage + 1} / ${_cards.length}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: _currentPage < _cards.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.ease,
                                );
                              }
                            : null,
                      ),
                    ],
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
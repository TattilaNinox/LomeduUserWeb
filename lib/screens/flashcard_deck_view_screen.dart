import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';
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
  bool _reorderMode = false;

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
        setState(() {
          _deckData = doc;
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
      return Scaffold(
          appBar: AppBar(title: const Text('Hiba')),
          body: const Center(child: Text('A pakli nem található.')));
    }

    final data = _deckData!.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Névtelen pakli';
    final flashcards =
        List<Map<String, dynamic>>.from(data['flashcards'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/notes'),
        ),
        actions: [
          IconButton(
            icon: Icon(_reorderMode ? Icons.check : Icons.swap_vert),
            tooltip: _reorderMode ? 'Rendezés mentése' : 'Átrendezés',
            onPressed: () async {
              if (_reorderMode) {
                // mentés
                await FirebaseFirestore.instance
                    .collection('notes')
                    .doc(widget.deckId)
                    .update({'flashcards': flashcards});
              }
              setState(() => _reorderMode = !_reorderMode);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'notes'),
          Expanded(
            child: flashcards.isEmpty
                ? const Center(child: Text('Ez a pakli üres.'))
                : _reorderMode
                    ? ReorderableListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: flashcards.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = flashcards.removeAt(oldIndex);
                            flashcards.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) => ListTile(
                          key: ValueKey(index),
                          title: FlippableCard(
                            frontText: flashcards[index]['front'] ?? '',
                            backText: flashcards[index]['back'] ?? '',
                            flipAxis: Axis.vertical,
                            interactive: false,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: flashcards.length,
                        itemBuilder: (context, index) {
                          return FlippableCard(
                            frontText: flashcards[index]['front'] ?? '',
                            backText: flashcards[index]['back'] ?? '',
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
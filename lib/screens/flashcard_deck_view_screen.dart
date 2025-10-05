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
            onPressed: () => context.go('/notes'),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: Theme.of(context).primaryColor,
                size: isMobile ? 20 : 22,
              ),
              onPressed: () => context.go('/notes'),
              tooltip: 'Vissza a jegyzetek listájához',
            ),
          ],
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
          : _reorderMode
              ? ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
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
                    return FlippableCard(
                      frontText: flashcards[index]['front'] ?? '',
                      backText: flashcards[index]['back'] ?? '',
                    );
                  },
                );

      if (isWide) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              title,
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
              onPressed: () => context.go('/notes'),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: Theme.of(context).primaryColor,
                  size: isMobile ? 20 : 22,
                ),
                onPressed: () => context.go('/notes'),
                tooltip: 'Vissza a jegyzetek listájához',
              ),
              IconButton(
                icon: Icon(_reorderMode ? Icons.check : Icons.swap_vert),
                tooltip: _reorderMode ? 'Rendezés mentése' : 'Átrendezés',
                onPressed: () async {
                  if (_reorderMode) {
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
              Expanded(child: content),
            ],
          ),
        );
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      
      return Scaffold(
        appBar: AppBar(
          title: Text(
            title,
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
            onPressed: () => context.go('/notes'),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: Theme.of(context).primaryColor,
                size: isMobile ? 20 : 22,
              ),
              onPressed: () => context.go('/notes'),
              tooltip: 'Vissza a jegyzetek listájához',
            ),
            IconButton(
              icon: Icon(_reorderMode ? Icons.check : Icons.swap_vert),
              tooltip: _reorderMode ? 'Rendezés mentése' : 'Átrendezés',
              onPressed: () async {
                if (_reorderMode) {
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
        drawer: Drawer(
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

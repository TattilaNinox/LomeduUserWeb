import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';
import 'dart:math';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

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
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'notes'),
          Expanded(
            child: flashcards.isEmpty
                ? const Center(child: Text('Ez a pakli üres.'))
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

class FlippableCard extends StatefulWidget {
  final String frontText;
  final String backText;

  const FlippableCard(
      {super.key, required this.frontText, required this.backText});

  @override
  State<FlippableCard> createState() => _FlippableCardState();
}

class _FlippableCardState extends State<FlippableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_controller.isCompleted || _controller.velocity > 0) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: _animation.value <= 0.5
                ? _buildCardSide(widget.frontText, true)
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCardSide(widget.backText, false),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardSide(String text, bool isFront) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isFront ? Colors.white : const Color(0xFFF5F5F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: isFront
              ? Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : CssHyphenatedText(text: text),
        ),
      ),
    );
  }
}

class CssHyphenatedText extends StatelessWidget {
  final String text;
  const CssHyphenatedText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final String viewType = 'css-hyphenated-text-$text';

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..append(html.ParagraphElement()
          ..text = text
          ..style.textAlign = 'justify'
          ..style.setProperty('hyphens', 'auto')
          ..style.color = '#374151'
          ..style.fontSize = '16px'
          ..style.width = '100%'),
    );

    return IgnorePointer(
      child: HtmlElementView(viewType: viewType),
    );
  }
}
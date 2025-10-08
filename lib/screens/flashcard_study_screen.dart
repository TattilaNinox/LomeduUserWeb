import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final String deckId;
  const FlashcardStudyScreen({super.key, required this.deckId});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  DocumentSnapshot? _deckData;
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _showAnswer = false;

  // Evaluation counters
  int _againCount = 0;
  int _hardCount = 0;
  int _goodCount = 0;
  int _easyCount = 0;

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

  void _showAnswerPressed() {
    setState(() {
      _showAnswer = true;
    });
  }

  void _evaluateCard(String evaluation) {
    setState(() {
      switch (evaluation) {
        case 'again':
          _againCount++;
          break;
        case 'hard':
          _hardCount++;
          break;
        case 'good':
          _goodCount++;
          break;
        case 'easy':
          _easyCount++;
          break;
      }
    });

    // Move to next card or finish
    if (_currentIndex < _getFlashcards().length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      // Show completion dialog or navigate back
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gratulálok!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sikeresen elvégezted a tanulást!'),
            const SizedBox(height: 16),
            Text('Újra: $_againCount'),
            Text('Nehéz: $_hardCount'),
            Text('Jó: $_goodCount'),
            Text('Könnyű: $_easyCount'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/notes');
            },
            child: const Text('Vissza'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFlashcards() {
    if (_deckData == null || !_deckData!.exists) return [];
    final data = _deckData!.data() as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['flashcards'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_deckData == null || !_deckData!.exists) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hiba'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('A pakli nem található.')),
      );
    }

    final flashcards = _getFlashcards();
    if (flashcards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tanulás'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Ez a pakli üres.')),
      );
    }

    final data = _deckData!.data() as Map<String, dynamic>;
    final deckTitle = data['title'] as String? ?? 'Névtelen pakli';
    final currentCard = flashcards[_currentIndex];
    final totalCards = flashcards.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          deckTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // Open drawer or menu
          },
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_currentIndex + 1} / $totalCards',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Evaluation counters
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCounter('Újra', _againCount, Colors.red),
                _buildCounter('Nehéz', _hardCount, Colors.orange),
                _buildCounter('Jó', _goodCount, Colors.green),
                _buildCounter('Könnyű', _easyCount, Colors.blue),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Main card content
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question section
                    const Text(
                      'Kérdés:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentCard['front'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Answer section
                    if (_showAnswer) ...[
                      const Text(
                        'Válasz:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentCard['back'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ] else ...[
                      // Show answer button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showAnswerPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Válasz megtekintése',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Evaluation buttons (only show when answer is visible)
          if (_showAnswer) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildEvaluationButton(
                          'Újra',
                          Colors.red,
                          () => _evaluateCard('again'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildEvaluationButton(
                          'Nehéz',
                          Colors.orange,
                          () => _evaluateCard('hard'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEvaluationButton(
                          'Jó',
                          Colors.green,
                          () => _evaluateCard('good'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildEvaluationButton(
                          'Könnyű',
                          Colors.blue,
                          () => _evaluateCard('easy'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationButton(
      String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

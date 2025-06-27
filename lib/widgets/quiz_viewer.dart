import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class QuizViewer extends StatefulWidget {
  final List<Map<String, dynamic>> questions;

  const QuizViewer({super.key, required this.questions});

  @override
  State<QuizViewer> createState() => _QuizViewerState();
}

class _QuizViewerState extends State<QuizViewer> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _answerChecked = false;

  late PageController _pageController;
  late AnimationController _cardFlipController;
  late Animation<double> _cardFlipAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardFlipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardFlipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardFlipController.dispose();
    super.dispose();
  }

  void _handleAnswer(int optionIndex) {
    if (_answerChecked) {
      if (_selectedOptionIndex == optionIndex) {
        if (_cardFlipController.isCompleted) {
          _cardFlipController.reverse();
        } else {
          _cardFlipController.forward();
        }
      }
      return;
    }

    setState(() {
      _selectedOptionIndex = optionIndex;
      _answerChecked = true;
      final isCorrect = widget.questions[_currentIndex]['options'][optionIndex]['isCorrect'] as bool;
      if (isCorrect) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );
      _cardFlipController.reverse();
    } else {
      _showResultDialog();
    }
  }
  
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _selectedOptionIndex = null;
      _answerChecked = false;
      _cardFlipController.reverse();
    });
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kvíz Befejezve', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Eredményed:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              '$_score / ${widget.questions.length}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pageController.jumpToPage(0);
              _onPageChanged(0); // Reset state
            },
            child: const Text('Újrapróbálkozás'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Center(child: Text('Nincsenek kérdések a kvízben.'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('Kvíz (${_currentIndex + 1}/${widget.questions.length})'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.questions.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final question = widget.questions[index];
                final options = (question['options'] as List).cast<Map<String, dynamic>>();
                return _buildQuestionPage(question, options);
              },
            ),
          ),
          _buildBottomNavBar(),
        ],
      ),
    );
  }
  
  Widget _buildQuestionPage(Map<String, dynamic> question, List<Map<String, dynamic>> options) {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question['question'],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...List.generate(options.length, (i) => _buildAnswerOption(options[i], i)),
        ],
      ),
    );
  }

  Widget _buildAnswerOption(Map<String, dynamic> option, int index) {
    bool isSelected = _selectedOptionIndex == index;
    
    return GestureDetector(
      onTap: () => _handleAnswer(index),
      child: AnimatedBuilder(
        animation: _cardFlipAnimation,
        builder: (context, child) {
          final rotation = isSelected ? _cardFlipAnimation.value * math.pi : 0.0;
          final isFlipped = isSelected && _cardFlipController.value > 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(rotation),
            child: isFlipped
                ? _buildCardBack(option)
                : _buildCardFront(option, index, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCardFront(Map<String, dynamic> option, int index, bool isSelected) {
    final bool isCorrect = option['isCorrect'] as bool;
    Color borderColor = Colors.grey.shade300;
    Color? iconColor;
    IconData? resultIcon;

    if (_answerChecked) {
      if (isCorrect) {
        borderColor = Colors.green;
        iconColor = Colors.green;
        resultIcon = Icons.check_circle;
      } else if (isSelected) {
        borderColor = Colors.red;
        iconColor = Colors.red;
        resultIcon = Icons.cancel;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(child: Text(option['text'], style: const TextStyle(fontSize: 16))),
          if (_answerChecked && isSelected)
            Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.threesixty, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Icon(resultIcon, color: iconColor),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildCardBack(Map<String, dynamic> option) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationX(math.pi),
        child: Center(
          child: Text(
            option['rationale'] ?? 'Nincs indoklás.',
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _answerChecked ? _nextQuestion : null,
        child: Text(
          _currentIndex < widget.questions.length - 1 ? 'Következő' : 'Befejezés',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
} 
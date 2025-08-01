import 'package:flutter/material.dart';

class QuizViewerDual extends StatefulWidget {
  final List<Map<String, dynamic>> questions;

  const QuizViewerDual({super.key, required this.questions});

  @override
  State<QuizViewerDual> createState() => _QuizViewerDualState();
}

class _QuizViewerDualState extends State<QuizViewerDual> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  final Set<int> _selectedOptionIndices = {};
  bool _answerChecked = false;

  late PageController _pageController;
  late AnimationController _cardFlipController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardFlipController.dispose();
    super.dispose();
  }

  void _toggleOption(int optionIndex) {
    if (_answerChecked) return; // Ne lehessen ellenőrzés után módosítani
    setState(() {
      if (_selectedOptionIndices.contains(optionIndex)) {
        _selectedOptionIndices.remove(optionIndex);
      } else {
        if (_selectedOptionIndices.length < 2) {
          _selectedOptionIndices.add(optionIndex);
        }
      }
    });
  }

  void _checkAnswer() {
    if (_answerChecked || _selectedOptionIndices.length != 2) return;

    setState(() {
      _answerChecked = true;
      final options = widget.questions[_currentIndex]['options'] as List<dynamic>;
      final correctIndices = <int>[];
      for (int i = 0; i < options.length; i++) {
        if (options[i]['isCorrect'] == true) correctIndices.add(i);
      }

      final isCorrect = _selectedOptionIndices.length == 2 &&
          _selectedOptionIndices.contains(correctIndices[0]) &&
          _selectedOptionIndices.contains(correctIndices[1]);
      if (isCorrect) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );
      setState(() {
        _selectedOptionIndices.clear();
        _answerChecked = false;
        _cardFlipController.reset();
      });
    } else {
      _showResultDialog();
    }
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
            Text('Eredményed:', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text('$_score / ${widget.questions.length}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pageController.jumpToPage(0);
              setState(() {
                _currentIndex = 0;
                _selectedOptionIndices.clear();
                _answerChecked = false;
                _score = 0;
              });
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.questions.length,
            color: Colors.blue,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.questions.length,
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
          const Text(
            'Jelöld ki a KÉT helyes választ!',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blueGrey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
    final isSelected = _selectedOptionIndices.contains(index);
    final isCorrectOption = option['isCorrect'] == true;

    Color tileColor = Colors.white;
    if (_answerChecked) {
      if (isCorrectOption) {
        tileColor = Colors.green.withValues(alpha: 0.2);
      } else if (isSelected && !isCorrectOption) {
        tileColor = Colors.red.withValues(alpha: 0.2);
      }
    } else if (isSelected) {
      tileColor = Colors.blue.withValues(alpha: 0.1);
    }

    return GestureDetector(
      onTap: () => _toggleOption(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue, width: 2),
                color: isSelected ? Colors.blue : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(option['text'], style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final canCheck = !_answerChecked && _selectedOptionIndices.length == 2;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: canCheck ? _checkAnswer : null,
            child: const Text('Válasz ellenőrzése'),
          ),
          ElevatedButton(
            onPressed: _answerChecked ? _nextQuestion : null,
            child: Text(_currentIndex < widget.questions.length - 1 ? 'Következő' : 'Eredmény'),
          ),
        ],
      ),
    );
  }
}

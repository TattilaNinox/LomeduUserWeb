import 'package:flutter/material.dart';
import 'dart:math' as math;

class QuizViewerDual extends StatefulWidget {
  final List<Map<String, dynamic>> questions;

  const QuizViewerDual({super.key, required this.questions});

  @override
  State<QuizViewerDual> createState() => _QuizViewerDualState();
}

class OptionCardDual extends StatefulWidget {
  final Map<String, dynamic> option;
  final bool isSelected;
  final bool answerChecked;
  final VoidCallback onSelect;

  const OptionCardDual({
    super.key,
    required this.option,
    required this.isSelected,
    required this.answerChecked,
    required this.onSelect,
  });

  @override
  State<OptionCardDual> createState() => _OptionCardDualState();
}

class _OptionCardDualState extends State<OptionCardDual> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OptionCardDual oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset flip when navigating to next question or reselecting
    if (!widget.answerChecked && oldWidget.answerChecked) {
      _controller.reset();
    }
    if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reset();
    }
  }

  void _handleTap() {
    if (!widget.answerChecked) {
      widget.onSelect();
    } else {
      if (!widget.isSelected) return; // Flip only selected option
      if (_controller.isCompleted) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCorrect = widget.option['isCorrect'] as bool? ?? false;
    bool showResult = widget.answerChecked;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final rotation = widget.isSelected ? _animation.value * math.pi : 0.0;
          final isFlipped = widget.isSelected && _controller.value > 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(rotation),
            child: isFlipped
                ? _buildCardBack()
                : _buildCardFront(isCorrect, showResult),
          );
        },
      ),
    );
  }

  Widget _buildCardFront(bool isCorrect, bool showResult) {
    Color borderColor = Colors.grey.shade300;
    Color? iconColor;
    IconData? resultIcon;

    if (showResult) {
      if (isCorrect) {
        borderColor = Colors.green;
        iconColor = Colors.green;
        resultIcon = Icons.check_circle;
      } else if (widget.isSelected) {
        borderColor = Colors.red;
        iconColor = Colors.red;
        resultIcon = Icons.cancel;
      }
    } else if (widget.isSelected) {
      borderColor = Colors.blue;
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: Text(widget.option['text'] ?? '', style: const TextStyle(fontSize: 16))),
          if (showResult && widget.isSelected)
            Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.threesixty, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Icon(resultIcon, color: iconColor),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
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
            widget.option['rationale'] ?? 'Nincs indoklás.',
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
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
    return OptionCardDual(
      option: option,
      isSelected: isSelected,
      answerChecked: _answerChecked,
      onSelect: () => _toggleOption(index),
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

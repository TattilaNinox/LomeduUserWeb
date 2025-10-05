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

class _OptionCardDualState extends State<OptionCardDual>
    with SingleTickerProviderStateMixin {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
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
      borderColor = Theme.of(context).primaryColor;
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
        border: Border.all(
          color: borderColor, 
          width: isMobile ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: isMobile ? 8 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.option['text'] ?? '',
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          if (showResult && widget.isSelected)
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.threesixty, 
                  color: Colors.grey, 
                  size: isMobile ? 18 : 20,
                ),
                const SizedBox(width: 8),
                Icon(
                  resultIcon, 
                  color: iconColor,
                  size: isMobile ? 20 : 24,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3), 
          width: isMobile ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: isMobile ? 8 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationX(math.pi),
        child: Center(
          child: Text(
            widget.option['rationale'] ?? 'Nincs indoklás.',
            style: TextStyle(
              color: Colors.white, 
              fontSize: isMobile ? 15 : 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _QuizViewerDualState extends State<QuizViewerDual>
    with TickerProviderStateMixin {
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
      final options =
          widget.questions[_currentIndex]['options'] as List<dynamic>;
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
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          'Kvíz (${_currentIndex + 1}/${widget.questions.length})',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.questions.length,
            color: Theme.of(context).primaryColor,
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
                final options =
                    (question['options'] as List).cast<Map<String, dynamic>>();
                return _buildQuestionPage(question, options);
              },
            ),
          ),
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(
      Map<String, dynamic> question, List<Map<String, dynamic>> options) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 16.0 : 24.0;
    final spacing = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Jelöld ki a KÉT helyes választ!',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: spacing),
          Text(
            question['question'],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 18 : 22,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing * 1.5),
          ...List.generate(
              options.length, (i) => _buildAnswerOption(options[i], i)),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final canCheck = !_answerChecked && _selectedOptionIndices.length == 2;
    
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 16 : 12, 
        horizontal: isMobile ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canCheck ? _checkAnswer : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canCheck 
                          ? Theme.of(context).primaryColor 
                          : Colors.grey.shade300,
                      foregroundColor: canCheck ? Colors.white : Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: canCheck ? 2 : 0,
                    ),
                    child: Text(
                      'Válasz ellenőrzése',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (_answerChecked) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        _currentIndex < widget.questions.length - 1
                            ? 'Következő'
                            : 'Eredmény',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: canCheck ? _checkAnswer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCheck 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey.shade300,
                    foregroundColor: canCheck ? Colors.white : Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Válasz ellenőrzése'),
                ),
                ElevatedButton(
                  onPressed: _answerChecked ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answerChecked 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey.shade300,
                    foregroundColor: _answerChecked ? Colors.white : Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_currentIndex < widget.questions.length - 1
                      ? 'Következő'
                      : 'Eredmény'),
                ),
              ],
            ),
    );
  }
}

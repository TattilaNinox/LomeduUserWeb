import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/note_content_service.dart';

class QuizViewerDual extends StatefulWidget {
  final List<Question> questions;
  final Function(QuizResult) onQuizComplete;
  final VoidCallback? onClose;

  const QuizViewerDual({
    super.key,
    required this.questions,
    required this.onQuizComplete,
    this.onClose,
  });

  @override
  State<QuizViewerDual> createState() => _QuizViewerDualState();
}

class _QuizViewerDualState extends State<QuizViewerDual> {
  int _currentQuestionIndex = 0;
  List<int> _selectedIndices = [];
  bool _isAnswered = false;
  List<QuestionResult> _questionResults = [];
  String? _noteContentPreview;
  bool _isLoadingPreview = false;

  Question get _currentQuestion => widget.questions[_currentQuestionIndex];
  bool get _isLastQuestion =>
      _currentQuestionIndex >= widget.questions.length - 1;
  bool get _canCheck => _selectedIndices.length == 2 && !_isAnswered;
  List<int> get _correctIndices => _currentQuestion.options
      .asMap()
      .entries
      .where((entry) => entry.value.isCorrect)
      .map((entry) => entry.key)
      .toList();

  @override
  void initState() {
    super.initState();
    _selectedIndices = [];
    _isAnswered = false;
    _loadNoteContentPreview();
  }

  Future<void> _loadNoteContentPreview() async {
    if (_currentQuestion.noteId == null) return;

    setState(() {
      _isLoadingPreview = true;
    });

    try {
      final preview = await NoteContentService.getNoteContentPreview(
          _currentQuestion.noteId!);
      if (mounted) {
        setState(() {
          _noteContentPreview = preview;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    }
  }

  void _selectOption(int index) {
    if (_isAnswered) return;

    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else if (_selectedIndices.length < 2) {
        _selectedIndices.add(index);
      } else {
        // Replace the first selected option
        _selectedIndices.removeAt(0);
        _selectedIndices.add(index);
      }
    });
  }

  void _checkAnswer() {
    if (!_canCheck) return;

    setState(() {
      _isAnswered = true;
    });

    // Check if the answer is correct
    final isCorrect = _selectedIndices.length == _correctIndices.length &&
        _selectedIndices.every((index) => _correctIndices.contains(index));

    // Store the result
    _questionResults.add(QuestionResult(
      question: _currentQuestion,
      selectedIndices: List.from(_selectedIndices),
      correctIndices: _correctIndices,
      isCorrect: isCorrect,
    ));
  }

  void _showRationaleForOption(Option option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Magyarázat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (option.rationale.isNotEmpty)
              Text(
                option.rationale,
                style: const TextStyle(fontSize: 14),
              )
            else
              Text(
                'Nincs elérhető magyarázat ehhez a válaszopcióhoz.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bezárás'),
          ),
        ],
      ),
    );
  }

  void _showRationaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Magyarázat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentQuestion.question,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._currentQuestion.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isSelected = _selectedIndices.contains(index);
                final isCorrect = option.isCorrect;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withValues(alpha: 0.1)
                        : isSelected
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green
                          : isSelected
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCorrect
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (option.rationale.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          option.rationale,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bezárás'),
          ),
        ],
      ),
    );
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      // Quiz completed
      final score = _questionResults.where((result) => result.isCorrect).length;
      final result = QuizResult(
        score: score,
        totalQuestions: widget.questions.length,
        questionResults: _questionResults,
      );
      widget.onQuizComplete(result);
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedIndices = [];
        _isAnswered = false;
        _noteContentPreview = null; // Clear previous preview
      });
      _loadNoteContentPreview(); // Load preview for new question
    }
  }

  Color _getOptionColor(int index) {
    if (!_isAnswered) {
      return _selectedIndices.contains(index)
          ? Colors.blue.withValues(alpha: 0.2)
          : Colors.transparent;
    }

    final option = _currentQuestion.options[index];
    if (option.isCorrect) {
      return Colors.green.withValues(alpha: 0.2);
    } else if (_selectedIndices.contains(index)) {
      return Colors.red.withValues(alpha: 0.2);
    }
    return Colors.transparent;
  }

  Color _getOptionBorderColor(int index) {
    if (!_isAnswered) {
      return _selectedIndices.contains(index) ? Colors.blue : Colors.grey;
    }

    final option = _currentQuestion.options[index];
    if (option.isCorrect) {
      return Colors.green;
    } else if (_selectedIndices.contains(index)) {
      return Colors.red;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Kvíz (${_currentQuestionIndex + 1}/${widget.questions.length})'),
        actions: [
          if (widget.onClose != null)
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / widget.questions.length,
              backgroundColor: Colors.grey.withValues(alpha: 0.3),
              valueColor:
                  AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 24),

            // Note content preview (if available)
            if (_currentQuestion.noteId != null) ...[
              Card(
                elevation: 2,
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kapcsolódó jegyzet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingPreview)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Betöltés...',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        )
                      else if (_noteContentPreview != null)
                        Text(
                          _noteContentPreview!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        )
                      else
                        Text(
                          'Nem sikerült betölteni a jegyzet tartalmát',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Question
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 17.0 : 20.0, // 15% kisebb padding mobil eszközön
                ),
                child: Text(
                  _currentQuestion.question,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 15.3 : 18, // 15% kisebb font mobil eszközön
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Options
            Expanded(
              child: ListView.builder(
                itemCount: _currentQuestion.options.length,
                itemBuilder: (context, index) {
                  final option = _currentQuestion.options[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _selectOption(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(
                          MediaQuery.of(context).size.width < 600 ? 13.6 : 16, // 15% kisebb padding mobil eszközön
                        ),
                        decoration: BoxDecoration(
                          color: _getOptionColor(index),
                          borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.width < 600 ? 10.2 : 12, // 15% kisebb border radius mobil eszközön
                          ),
                          border: Border.all(
                            color: _getOptionBorderColor(index),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width < 600 ? 20.4 : 24, // 15% kisebb checkbox mobil eszközön
                              height: MediaQuery.of(context).size.width < 600 ? 20.4 : 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getOptionBorderColor(index),
                                  width: 2,
                                ),
                                color: _selectedIndices.contains(index)
                                    ? _getOptionBorderColor(index)
                                    : Colors.transparent,
                              ),
                              child: _selectedIndices.contains(index)
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: MediaQuery.of(context).size.width < 600 ? 13.6 : 16, // 15% kisebb ikon mobil eszközön
                                    )
                                  : null,
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width < 600 ? 13.6 : 16), // 15% kisebb spacing mobil eszközön
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width < 600 ? 13.6 : 16, // 15% kisebb font mobil eszközön
                                  fontWeight: _selectedIndices.contains(index)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_isAnswered) ...[
                              // Show check/cancel icons
                              if (option.isCorrect)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              if (_selectedIndices.contains(index) &&
                                  !option.isCorrect)
                                const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              // Show info icon for rationale (if option is correct OR was selected)
                              if (option.isCorrect ||
                                  _selectedIndices.contains(index))
                                IconButton(
                                  onPressed: () =>
                                      _showRationaleForOption(option),
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  tooltip: 'Magyarázat',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                if (_isAnswered) ...[
                  IconButton(
                    onPressed: _showRationaleDialog,
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Magyarázat',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canCheck ? _checkAnswer : null,
                    child: Text(_isAnswered
                        ? 'Ellenőrizve'
                        : 'Ellenőrzés (${_selectedIndices.length}/2)'),
                  ),
                ),
                if (_isAnswered) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      child: Text(_isLastQuestion ? 'Befejezés' : 'Következő'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

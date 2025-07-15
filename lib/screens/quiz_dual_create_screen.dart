import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';
import '../widgets/quiz_viewer_dual.dart';

class QuizDualCreateScreen extends StatefulWidget {
  const QuizDualCreateScreen({super.key});

  @override
  State<QuizDualCreateScreen> createState() => _QuizDualCreateScreenState();
}

class _QuizDualCreateScreenState extends State<QuizDualCreateScreen> {
  final _titleController = TextEditingController();
  String? _selectedCategory;
  String? _selectedQuestionBankId;
  bool _isSaving = false;
  List<String> _categories = [];
  List<DocumentSnapshot> _questionBanks = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCategories();
    await _loadQuestionBanks();
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    if (mounted) _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
  }

  Future<void> _loadQuestionBanks() async {
    final snapshot = await FirebaseFirestore.instance.collection('question_banks').get();
    final compatibleBanks = <DocumentSnapshot>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
      if (questions.isEmpty) continue;
      final allValid = questions.every((q) {
        final options = (q['options'] as List).cast<Map<String, dynamic>>();
        final correctCnt = options.where((o) => o['isCorrect'] == true).length;
        return correctCnt == 2;
      });
      if (allValid) compatibleBanks.add(doc);
    }
    if (mounted) _questionBanks = compatibleBanks;
  }

  Future<void> _createQuiz() async {
    if (_titleController.text.isEmpty || _selectedCategory == null || _selectedQuestionBankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minden mező kitöltése kötelező!')));
      return;
    }

    final trimmedTitle = _titleController.text.trim();
    final dupSnap = await FirebaseFirestore.instance.collection('notes').where('title', isEqualTo: trimmedTitle).limit(1).get();
    if (dupSnap.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Már létezik ilyen című jegyzet!')));
      return;
    }

    final bankDoc = await FirebaseFirestore.instance.collection('question_banks').doc(_selectedQuestionBankId).get();
    if (!bankDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hiba: A kérdésbank nem található.')));
      return;
    }
    final bankData = bankDoc.data()!;
    final questions = List<Map<String, dynamic>>.from(bankData['questions'] ?? []);
    final invalidQuestions = questions.where((q) {
      final options = (q['options'] as List).cast<Map<String, dynamic>>();
      final correctCount = options.where((o) => o['isCorrect'] == true).length;
      return correctCount != 2;
    }).toList();

    if (invalidQuestions.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A kiválasztott kérdésbank minden kérdésének pontosan 2 helyes válasszal kell rendelkeznie.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('notes').add({
        'title': _titleController.text,
        'category': _selectedCategory,
        'questionBankId': _selectedQuestionBankId,
        'type': 'dynamic_quiz_dual',
        'status': 'Draft',
        'createdAt': Timestamp.now(),
        'modified': Timestamp.now(),
      });
      if (mounted) context.go('/notes');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBanks = _selectedCategory == null
        ? _questionBanks
        : _questionBanks.where((bank) => bank['category'] == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Új 2-válaszos Dinamikus Kvíz'),
        actions: [
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _createQuiz,
            icon: _isSaving ? const CircularProgressIndicator() : const Icon(Icons.save),
            label: const Text('Mentés'),
          )
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'dynamic_quiz_dual_create'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Kvíz címe')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() {
                      _selectedCategory = val;
                      _selectedQuestionBankId = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Kategória'),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedCategory != null)
                    DropdownButtonFormField<String>(
                      value: _selectedQuestionBankId,
                      items: filteredBanks.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
                      onChanged: (val) => setState(() => _selectedQuestionBankId = val),
                      decoration: const InputDecoration(labelText: 'Válassz Kérdésbankot'),
                    ),
                  const SizedBox(height: 24),
                  if (_selectedQuestionBankId != null)
                    ElevatedButton.icon(
                      onPressed: _showQuizPreview,
                      icon: const Icon(Icons.visibility),
                      label: const Text('Kvíz Előnézet'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuizPreview() async {
    if (_selectedQuestionBankId == null) return;

    final bankDoc = await FirebaseFirestore.instance.collection('question_banks').doc(_selectedQuestionBankId).get();
    if (!bankDoc.exists) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hiba: A kérdésbank nem található.')));
      return;
    }
    final bank = bankDoc.data()!;
    final questions = List<Map<String, dynamic>>.from(bank['questions'] ?? []);
    questions.shuffle();
    final selectedQuestions = questions.take(10).toList();

    if (selectedQuestions.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ez a kérdésbank nem tartalmaz kérdéseket.')));
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: const EdgeInsets.all(8),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: QuizViewerDual(questions: selectedQuestions),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bezárás'),
            )
          ],
        ),
      );
    }
  }
} 
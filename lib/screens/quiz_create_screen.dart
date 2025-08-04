import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';
import '../widgets/quiz_viewer.dart';

class QuizCreateScreen extends StatefulWidget {
  const QuizCreateScreen({super.key});

  @override
  State<QuizCreateScreen> createState() => _QuizCreateScreenState();
}

class _QuizCreateScreenState extends State<QuizCreateScreen> {
  final _titleController = TextEditingController();
  String? _selectedCategory;
  String? _selectedQuestionBankId;
  bool _isSaving = false;
  List<String> _categories = [];
  List<String> _sciences = [];
  String? _selectedScience;
  List<DocumentSnapshot> _questionBanks = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadSciences();
    await _loadCategories();
    await _loadQuestionBanks();
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    if (_selectedScience == null) {
      if (mounted) {
        setState(() {
          _categories = [];
        });
      }
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('science', isEqualTo: _selectedScience)
        .get();
    if (mounted) {
      setState(() {
        _categories =
            snapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    }
  }

  Future<void> _loadSciences() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('sciences').get();
    if (mounted) {
      setState(() {
        _sciences = snapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    }
  }

  Future<void> _loadQuestionBanks() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('question_banks').get();
    if (mounted) _questionBanks = snapshot.docs;
  }

  Future<void> _createQuiz() async {
    if (_titleController.text.isEmpty ||
        _selectedScience == null ||
        _selectedCategory == null ||
        _selectedQuestionBankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minden mező kitöltése kötelező!')));
      return;
    }

    final trimmedTitle = _titleController.text.trim();
    final dupSnap = await FirebaseFirestore.instance
        .collection('notes')
        .where('title', isEqualTo: trimmedTitle)
        .limit(1)
        .get();
    if (dupSnap.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Már létezik ilyen című jegyzet!')));
      }
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('notes').add({
        'title': _titleController.text,
        'category': _selectedCategory,
        'science': _selectedScience,
        'questionBankId': _selectedQuestionBankId,
        'type': 'dynamic_quiz',
        'status': 'Draft',
        'createdAt': Timestamp.now(),
        'modified': Timestamp.now(),
      });
      if (mounted) context.go('/notes');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hiba: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBanks = _selectedCategory == null
        ? _questionBanks
        : _questionBanks
            .where((bank) => bank['category'] == _selectedCategory)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Új Dinamikus Kvíz'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/notes'),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => context.go('/notes'),
            child: const Text('Mégse'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _createQuiz,
            icon: _isSaving
                ? const CircularProgressIndicator()
                : const Icon(Icons.save),
            label: const Text('Mentés'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'dynamic_quiz_create'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  TextField(
                      controller: _titleController,
                      decoration:
                          const InputDecoration(labelText: 'Kvíz címe')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedScience,
                    items: _sciences
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selectedScience = val;
                      _selectedCategory = null;
                      _selectedQuestionBankId = null;
                      _loadCategories();
                    }),
                    decoration: const InputDecoration(labelText: 'Tudomány'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: _selectedScience == null
                        ? null
                        : (val) => setState(() {
                              _selectedCategory = val;
                              _selectedQuestionBankId = null;
                            }),
                    decoration: InputDecoration(
                      labelText: 'Kategória',
                      fillColor:
                          _selectedScience == null ? Colors.grey[100] : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedCategory != null)
                    DropdownButtonFormField<String>(
                      value: _selectedQuestionBankId,
                      items: filteredBanks
                          .map((doc) => DropdownMenuItem(
                              value: doc.id, child: Text(doc['name'])))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedQuestionBankId = val),
                      decoration: const InputDecoration(
                          labelText: 'Válassz Kérdésbankot'),
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

    final bankDoc = await FirebaseFirestore.instance
        .collection('question_banks')
        .doc(_selectedQuestionBankId)
        .get();
    if (!bankDoc.exists) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hiba: A kérdésbank nem található.')));
      return;
    }
    final bank = bankDoc.data()!;
    final questions = List<Map<String, dynamic>>.from(bank['questions'] ?? []);
    questions.shuffle();
    final selectedQuestions = questions.take(10).toList();

    if (selectedQuestions.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ez a kérdésbank nem tartalmaz kérdéseket.')));
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
            child: QuizViewer(questions: selectedQuestions),
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

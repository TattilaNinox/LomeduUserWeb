import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';

class QuizEditScreen extends StatefulWidget {
  final String noteId;
  const QuizEditScreen({super.key, required this.noteId});

  @override
  State<QuizEditScreen> createState() => _QuizEditScreenState();
}

class _QuizEditScreenState extends State<QuizEditScreen> {
  final _titleController = TextEditingController();
  String? _selectedCategory;
  String? _selectedQuestionBankId;
  bool _isSaving = false;
  bool _isLoading = true;
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
    await _loadQuizData();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    if(mounted) _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
  }

  Future<void> _loadQuestionBanks() async {
    final snapshot = await FirebaseFirestore.instance.collection('question_banks').get();
    if(mounted) _questionBanks = snapshot.docs;
  }
  
  Future<void> _loadQuizData() async {
    final doc = await FirebaseFirestore.instance.collection('notes').doc(widget.noteId).get();
    if (doc.exists) {
      final data = doc.data()!;
      _titleController.text = data['title'];
      _selectedCategory = data['category'];
      _selectedQuestionBankId = data['questionBankId'];
    }
  }

  Future<void> _updateQuiz() async {
    if (_titleController.text.isEmpty || _selectedCategory == null || _selectedQuestionBankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minden mező kitöltése kötelező!')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('notes').doc(widget.noteId).update({
        'title': _titleController.text,
        'category': _selectedCategory,
        'questionBankId': _selectedQuestionBankId,
        'modified': Timestamp.now(),
      });
      if (mounted) context.go('/notes');
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Betöltés...')));
    }
        
    final filteredBanks = _selectedCategory == null
        ? _questionBanks
        : _questionBanks.where((bank) => bank['category'] == _selectedCategory).toList();
        
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvíz Szerkesztése'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/notes'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/notes'),
            child: const Text('Mégse'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _updateQuiz,
            icon: _isSaving ? const CircularProgressIndicator() : const Icon(Icons.save),
            label: const Text('Mentés'),
          )
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'notes'),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
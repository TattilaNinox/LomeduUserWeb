import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'package:file_selector/file_selector.dart';

class QuestionBankEditScreen extends StatefulWidget {
  final String bankId;
  const QuestionBankEditScreen({super.key, required this.bankId});

  @override
  State<QuestionBankEditScreen> createState() => _QuestionBankEditScreenState();
}

class _QuestionBankEditScreenState extends State<QuestionBankEditScreen> {
  final _nameController = TextEditingController();
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCategories();
    await _loadBank();
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    if(mounted) {
      _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    }
  }

  Future<void> _loadBank() async {
    final doc = await FirebaseFirestore.instance.collection('question_banks').doc(widget.bankId).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _selectedCategory = data['category'];
      _questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveBank() async {
    await FirebaseFirestore.instance.collection('question_banks').doc(widget.bankId).update({
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'questions': _questions,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kérdésbank mentve!')));
    }
  }
  
  void _addQuestion() {
    setState(() {
      _questions.add({
        'question': 'Új kérdés',
        'options': [
          {'text': 'Válasz 1', 'isCorrect': true, 'rationale': ''},
          {'text': 'Válasz 2', 'isCorrect': false, 'rationale': ''},
          {'text': 'Válasz 3', 'isCorrect': false, 'rationale': ''},
          {'text': 'Válasz 4', 'isCorrect': false, 'rationale': ''},
        ]
      });
    });
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final Sheet sheetObject = excel['Kérdések'];

    // Fejléc
    final header = [
      'Kérdés',
      'Válasz 1', 'V1 Helyes', 'V1 Indoklás',
      'Válasz 2', 'V2 Helyes', 'V2 Indoklás',
      'Válasz 3', 'V3 Helyes', 'V3 Indoklás',
      'Válasz 4', 'V4 Helyes', 'V4 Indoklás',
    ];
    sheetObject.appendRow(header);

    // Adatsorok
    for (final question in _questions) {
      final List<dynamic> row = [];
      row.add(question['question'] as String? ?? '');
      final options = (question['options'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final option in options) {
        row.add(option['text'] as String? ?? '');
        row.add((option['isCorrect'] as bool? ?? false) ? 'IGAZ' : 'HAMIS');
        row.add(option['rationale'] as String? ?? '');
      }
      sheetObject.appendRow(row);
    }

    final bytes = excel.save();
    if (bytes != null) {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', '${_nameController.text.trim()}.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _importFromExcel() async {
    const typeGroup = XTypeGroup(label: 'Excel', extensions: ['xlsx']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hiba: Nem található munkalap az Excel fájlban.')));
      return;
    }

    final newQuestions = <Map<String, dynamic>>[];
    // Az első sor a fejléc, kihagyjuk (i=1)
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => cell == null || cell.value.toString().trim().isEmpty)) continue; // Üres sorok kihagyása

      try {
        final questionText = row[0]?.value.toString().trim() ?? '';
        if (questionText.isEmpty) continue; // Kérdés nélküli sorok kihagyása

        final options = <Map<String, dynamic>>[];
        for (var j = 0; j < 4; j++) {
          final optionText = row[1 + j * 3]?.value.toString().trim() ?? '';
          final isCorrectStr = row[2 + j * 3]?.value.toString().trim().toUpperCase() ?? 'HAMIS';
          final rationale = row[3 + j * 3]?.value.toString().trim() ?? '';
          
          options.add({
            'text': optionText,
            'isCorrect': isCorrectStr == 'IGAZ',
            'rationale': rationale,
          });
        }
        
        // Ellenőrizzük, hogy van-e pontosan egy helyes válasz
        if (options.where((opt) => opt['isCorrect'] == true).length != 1) {
          throw Exception('Minden kérdéshez pontosan egy helyes választ kell megadni (sor: ${i + 1})');
        }

        newQuestions.add({
          'question': questionText,
          'options': options,
        });
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba a(z) ${i+1}. sor feldolgozásakor: $e')));
        return; // Hiba esetén leállítjuk az importálást
      }
    }

    // Megerősítő dialógus
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importálás megerősítése'),
        content: Text('Biztosan felülírja a jelenlegi ${this._questions.length} kérdést a fájlban található ${newQuestions.length} kérdéssel?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Mégse')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.orange), child: const Text('Felülírás')),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        this._questions = newQuestions;
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importálás sikeres! Ne felejts el menteni.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Betöltés...')), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kérdésbank Szerkesztése'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToExcel,
            tooltip: 'Exportálás Excelbe',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importFromExcel,
            tooltip: 'Importálás Excelből',
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveBank,
            tooltip: 'Mentés',
          ),
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'question_banks'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Kérdésbank neve'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          items: _categories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Kategória',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        return _buildQuestionEditor(_questions[index], index);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuestion,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuestionEditor(Map<String, dynamic> question, int index) {
    // A kérdés szövegének vezérlője
    final questionController = TextEditingController(text: question['question'] as String? ?? '');
    questionController.addListener(() {
      _questions[index]['question'] = questionController.text;
    });

    // A válaszok vezérlői
    final options = (question['options'] as List<dynamic>).cast<Map<String, dynamic>>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: questionController,
                    decoration: InputDecoration(labelText: 'Kérdés ${index + 1}'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() => _questions.removeAt(index));
                  },
                )
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(4, (optionIndex) {
              final option = options[optionIndex];
              final optionController = TextEditingController(text: option['text'] as String? ?? '');
              optionController.addListener(() {
                options[optionIndex]['text'] = optionController.text;
              });

              final rationaleController = TextEditingController(text: option['rationale'] as String? ?? '');
              rationaleController.addListener(() {
                options[optionIndex]['rationale'] = rationaleController.text;
              });

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: option['isCorrect'] as bool? ?? false,
                      onChanged: (value) {
                        setState(() {
                          for (var opt in options) {
                            opt['isCorrect'] = false;
                          }
                          option['isCorrect'] = true;
                        });
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: optionController,
                        decoration: InputDecoration(labelText: 'Válasz ${optionIndex + 1}'),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: TextField(
                          controller: rationaleController,
                          decoration: InputDecoration(labelText: 'Indoklás ${optionIndex + 1}'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';
import 'package:excel/excel.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:file_selector/file_selector.dart';

class DeckEditScreen extends StatefulWidget {
  final String deckId;
  const DeckEditScreen({super.key, required this.deckId});

  @override
  State<DeckEditScreen> createState() => _DeckEditScreenState();
}

class _DeckEditScreenState extends State<DeckEditScreen> {
  final _titleController = TextEditingController();
  String? _selectedCategory;
  List<Map<String, dynamic>> _flashcards = [];
  bool _isLoading = true;
  Map<String, String> _categories = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadCategories();
    await _loadDeckDetails();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDeckDetails() async {
    final doc = await FirebaseFirestore.instance.collection('notes').doc(widget.deckId).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      _titleController.text = data['title'];
      _flashcards = List<Map<String, dynamic>>.from(data['flashcards'] ?? []);
      setState(() {
        _selectedCategory = data['category_id'];
      });
    }
  }
  
  Future<void> _saveDeck() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance.collection('notes').doc(widget.deckId).update({
        'title': _titleController.text.trim(),
        'category_id': _selectedCategory,
        'category': _categories[_selectedCategory] ?? '',
        'flashcards': _flashcards,
        'modified': Timestamp.now(),
      });

      if (!mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text('Pakli mentve!')));
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;
      router.go('/decks');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Hiba a mentés során: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final Sheet sheetObject = excel['Tanulókártyák'];
    final header = ['Előlap', 'Hátlap'];
    sheetObject.appendRow(header);

    for (final card in _flashcards) {
      final row = [
        card['front'] as String? ?? '',
        card['back'] as String? ?? '',
      ];
      sheetObject.appendRow(row);
    }
    final bytes = excel.save();
    if (bytes != null) {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', '${_titleController.text.trim()}.xlsx')
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hiba: Nem található munkalap.')));
      return;
    }
    final newFlashcards = <Map<String, dynamic>>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => cell == null || cell.value.toString().trim().isEmpty)) continue;
      try {
        final frontText = row[0]?.value.toString().trim() ?? '';
        final backText = row[1]?.value.toString().trim() ?? '';
        if (frontText.isEmpty && backText.isEmpty) continue;
        
        newFlashcards.add({'front': frontText, 'back': backText});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba a(z) ${i+1}. sor feldolgozásakor: $e')));
        return;
      }
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importálás megerősítése'),
        content: Text('Biztosan felülírja a jelenlegi ${_flashcards.length} kártyát a fájlban található ${newFlashcards.length} kártyával?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Mégse')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.orange), child: const Text('Felülírás')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _flashcards = newFlashcards);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importálás sikeres! Ne felejts el menteni.')));
    }
  }

  void _addFlashcard() {
    setState(() {
      _flashcards.add({
        'front': 'Új kártya - Előlap',
        'back': 'Új kártya - Hátlap',
      });
    });
  }

  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    if(mounted) {
      setState(() {
        _categories = {for (var doc in snapshot.docs) doc.id: doc['name'] as String};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Betöltés...')), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanulókártya pakli szerkesztése'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/decks'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportToExcel, tooltip: 'Exportálás Excelbe'),
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _importFromExcel, tooltip: 'Importálás Excelből'),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveDeck, tooltip: 'Mentés'),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'decks'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Pakli címe'),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategory = val);
                    },
                    decoration: const InputDecoration(labelText: 'Kategória'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Tanulókártyák', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _flashcards.length,
                      itemBuilder: (context, index) {
                        return _buildFlashcardEditor(_flashcards[index], index);
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
        onPressed: _addFlashcard,
        tooltip: 'Új kártya hozzáadása',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFlashcardEditor(Map<String, dynamic> card, int index) {
    final frontController = TextEditingController(text: card['front'] as String? ?? '');
    frontController.addListener(() => _flashcards[index]['front'] = frontController.text);

    final backController = TextEditingController(text: card['back'] as String? ?? '');
    backController.addListener(() => _flashcards[index]['back'] = backController.text);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kártya ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _flashcards.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: frontController,
              decoration: const InputDecoration(labelText: 'Előlap'),
              maxLines: null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: backController,
              decoration: const InputDecoration(labelText: 'Hátlap'),
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }
} 
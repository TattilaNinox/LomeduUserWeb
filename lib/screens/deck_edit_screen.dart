import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar.dart';
import 'dart:async';

class DeckEditScreen extends StatefulWidget {
  final String deckId;
  const DeckEditScreen({super.key, required this.deckId});

  @override
  State<DeckEditScreen> createState() => _DeckEditScreenState();
}

class _DeckEditScreenState extends State<DeckEditScreen> {
  final _titleCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadDeckDetails();
    _titleCtrl.addListener(_onDeckDetailsChanged);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onDeckDetailsChanged);
    _titleCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDeckDetails() async {
    final doc = await FirebaseFirestore.instance.collection('notes').doc(widget.deckId).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      _titleCtrl.text = data['title'];
    }
  }

  void _onDeckDetailsChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      FirebaseFirestore.instance.collection('notes').doc(widget.deckId).update({
        'title': _titleCtrl.text,
        'modified': Timestamp.now(),
      });
    });
  }

  void _showNotePicker() async {
    final selectedNoteIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => const NotePickerDialog(),
    );

    if (selectedNoteIds != null && selectedNoteIds.isNotEmpty) {
      await FirebaseFirestore.instance.collection('notes').doc(widget.deckId).update({
        'card_ids': FieldValue.arrayUnion(selectedNoteIds),
      });
    }
  }
  
  void _removeCard(String cardId) {
    FirebaseFirestore.instance.collection('notes').doc(widget.deckId).update({
      'card_ids': FieldValue.arrayRemove([cardId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Köteg szerkesztése'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/decks'),
        ),
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
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Köteg címe'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kártyák a kötegben', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: _showNotePicker,
                        icon: const Icon(Icons.add),
                        label: const Text('Jegyzet hozzáadása'),
                      )
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('notes').doc(widget.deckId).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        final cardIds = List<String>.from(data['card_ids'] ?? []);

                        if (cardIds.isEmpty) return const Center(child: Text('Nincsenek kártyák a kötegben.'));

                        return ReorderableListView.builder(
                          itemCount: cardIds.length,
                          itemBuilder: (context, index) {
                            return FutureBuilder<DocumentSnapshot>(
                              key: ValueKey(cardIds[index]),
                              future: FirebaseFirestore.instance.collection('notes').doc(cardIds[index]).get(),
                              builder: (context, cardSnapshot) {
                                if (!cardSnapshot.hasData) return const ListTile(title: Text('Betöltés...'));
                                final cardData = cardSnapshot.data!.data() as Map<String, dynamic>;
                                return ListTile(
                                  leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                                  title: Text(cardData['title'] ?? 'Névtelen jegyzet'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () => _removeCard(cardIds[index]),
                                  ),
                                );
                              },
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) newIndex -= 1;
                            final item = cardIds.removeAt(oldIndex);
                            cardIds.insert(newIndex, item);
                            FirebaseFirestore.instance.collection('notes').doc(widget.deckId).update({'card_ids': cardIds});
                          },
                        );
                      },
                    ),
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

class NotePickerDialog extends StatefulWidget {
  const NotePickerDialog({super.key});

  @override
  State<NotePickerDialog> createState() => _NotePickerDialogState();
}

class _NotePickerDialogState extends State<NotePickerDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Jegyzetek kiválasztása'),
      content: SizedBox(
        width: 500,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notes')
              .where('type', isEqualTo: 'interactive')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(
              children: snapshot.data!.docs.map((doc) {
                final isSelected = _selectedIds.contains(doc.id);
                return CheckboxListTile(
                  title: Text(doc['title']),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedIds.add(doc.id);
                      } else {
                        _selectedIds.remove(doc.id);
                      }
                    });
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mégse')),
        TextButton(onPressed: () => Navigator.of(context).pop(_selectedIds.toList()), child: const Text('Hozzáadás')),
      ],
    );
  }
} 
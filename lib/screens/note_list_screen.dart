import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/sidebar.dart';
import '../widgets/header.dart';
import '../widgets/filters.dart';
import '../widgets/note_table.dart';

/// A jegyzetek listáját megjelenítő főképernyő.
///
/// Ez egy `StatefulWidget`, mivel a felhasználó által beállított szűrési és
/// keresési feltételeket az állapotában (`State`) kell tárolnia és kezelnie.
/// A képernyő felépítése több al-widgetre van bontva a jobb átláthatóság érdekében
/// (`Sidebar`, `Header`, `Filters`, `NoteTable`).
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

/// A `NoteListScreen` állapotát kezelő osztály.
class _NoteListScreenState extends State<NoteListScreen> {
  // Állapotváltozók a szűrési és keresési feltételek tárolására.
  String _searchText = '';
  String? _selectedStatus;
  String? _selectedCategory;
  String? _selectedTag;
  String? _selectedType;

  // Listák a Firestore-ból betöltött kategóriák és címkék tárolására.
  // Ezeket a `Filters` widget kapja meg, hogy fel tudja tölteni a legördülő menüket.
  List<String> _categories = [];
  List<String> _tags = [];

  /// A widget életciklusának `initState` metódusa.
  ///
  /// Akkor hívódik meg, amikor a widget először bekerül a widget-fába.
  /// Itt indítjuk el a kategóriák és címkék betöltését a Firestore-ból.
  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTags();
  }

  /// Betölti a kategóriákat a Firestore `categories` kollekciójából.
  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    // A `setState` frissíti a widget állapotát a betöltött adatokkal,
    // ami újraépíti a UI-t, és a `Filters` widget megkapja a kategóriákat.
    setState(() {
      _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  /// Betölti a címkéket a Firestore `tags` kollekciójából.
  Future<void> _loadTags() async {
    final notesSnapshot = await FirebaseFirestore.instance.collection('notes').get();
    final allTags = <String>{}; // Set-et használunk a duplikátumok automatikus kezelésére

    for (final doc in notesSnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('tags') && data['tags'] is List) {
        final tags = List<String>.from(data['tags']);
        allTags.addAll(tags);
      }
    }
    
    if (mounted) {
      setState(() {
        _tags = allTags.toList()..sort(); // Opcionális: ABC sorrendbe rendezzük a listát
      });
    }
  }

  // Az alábbi metódusok ún. "callback" függvények, amelyeket a gyermek
  // widget-ek (`Header`, `Filters`) hívnak meg, amikor a felhasználó
  // módosítja a keresési vagy szűrési feltételeket.

  /// Frissíti a keresőszöveget a `Header` widgetből kapott értékkel.
  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
    });
  }

  /// Frissíti a kiválasztott státuszt a `Filters` widgetből.
  void _onStatusChanged(String? value) {
    setState(() {
      _selectedStatus = value;
    });
  }

  /// Frissíti a kiválasztott kategóriát a `Filters` widgetből.
  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value;
    });
  }

  /// Frissíti a kiválasztott címkét a `Filters` widgetből.
  void _onTagChanged(String? value) {
    setState(() => _selectedTag = value);
  }

  /// Frissíti a kiválasztott típust.
  void _onTypeChanged(String? value) {
    setState(() => _selectedType = value);
  }


  /// Törli az összes aktív szűrőt.
  void _onClearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedCategory = null;
      _selectedTag = null;
      _selectedType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 250, 251),
      // A képernyő fő elrendezése egy `Row` (sor), amely két részből áll:
      // a bal oldali `Sidebar` és a jobb oldali, `Expanded` tartalom.
      body: Row(
        children: [
          // Az oldalsó menüsáv. A `selectedMenu: 'notes'` paraméter jelzi,
          // hogy melyik menüpont legyen aktív.
          const Sidebar(selectedMenu: 'notes'),
          // Az `Expanded` widget kitölti a rendelkezésre álló vízszintes teret.
          Expanded(
            // A jobb oldali rész egy `Column` (oszlop), amely egymás alá
            // helyezi a fejlécet, a szűrőket és a jegyzet táblázatot.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A fejléc, amely a keresőmezőt tartalmazza.
                // A `onSearchChanged` callback-en keresztül kapja meg a szülő
                // a keresőmezőbe írt szöveget.
                Header(
                  onSearchChanged: _onSearchChanged,
                ),
                // A szűrőket tartalmazó sáv. Megkapja a betöltött kategóriákat,
                // címkéket, az aktuálisan kiválasztott szűrőértékeket és
                // a callback függvényeket a szűrők állapotának módosításához.
                Filters(
                  categories: _categories,
                  tags: _tags,
                  selectedStatus: _selectedStatus,
                  selectedCategory: _selectedCategory,
                  selectedTag: _selectedTag,
                  selectedType: _selectedType,
                  onStatusChanged: _onStatusChanged,
                  onCategoryChanged: _onCategoryChanged,
                  onTagChanged: _onTagChanged,
                  onTypeChanged: _onTypeChanged,
                  onClearFilters: _onClearFilters,
                ),
                // A jegyzeteket megjelenítő táblázat.
                // Megkapja a szülő widget állapotában lévő összes keresési
                // és szűrési feltételt, hogy azok alapján tudja megjeleníteni a
                // megfelelő jegyzeteket.
                NoteTable(
                  searchText: _searchText,
                  selectedStatus: _selectedStatus,
                  selectedCategory: _selectedCategory,
                  selectedTag: _selectedTag,
                  selectedType: _selectedType,
                                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/firebase_config.dart';

import '../utils/filter_storage.dart';
import '../widgets/sidebar.dart';
import '../widgets/header.dart';
import '../widgets/filters.dart';
import '../widgets/note_card_grid.dart';

/// A jegyzetek listáját megjelenítő főképernyő.
///
/// Ez egy `StatefulWidget`, mivel a felhasználó által beállított szűrési és
/// keresési feltételeket az állapotában (`State`) kell tárolnia és kezelnie.
/// A képernyő felépítése több al-widgetre van bontva a jobb átláthatóság érdekében
/// (`Sidebar`, `Header`, `Filters`, `NoteTable`).
class NoteListScreen extends StatefulWidget {
  final String? initialSearch;
  final String? initialStatus;
  final String? initialCategory;
  final String? initialScience;
  final String? initialTag;
  final String? initialType;

  const NoteListScreen({
    super.key,
    this.initialSearch,
    this.initialStatus,
    this.initialCategory,
    this.initialScience,
    this.initialTag,
    this.initialType,
  });

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

/// A `NoteListScreen` állapotát kezelő osztály.
class _NoteListScreenState extends State<NoteListScreen> {
  // Állapotváltozók a szűrési és keresési feltételek tárolására.
  String _searchText = '';
  String? _selectedStatus;
  String? _selectedCategory;
  String? _selectedScience;
  String? _selectedTag;
  String? _selectedType;

  // TextEditingController a keresőmező vezérléséhez
  final _searchController = TextEditingController();

  // Listák a Firestore-ból betöltött kategóriák, tudományok és címkék tárolására.
  List<String> _categories = [];
  List<String> _sciences = [];
  List<String> _tags = [];

  /// A widget életciklusának `initState` metódusa.
  ///
  /// Akkor hívódik meg, amikor a widget először bekerül a widget-fába.
  /// Itt indítjuk el a kategóriák és címkék betöltését a Firestore-ból.
  /// Betölti a mentett szűrőket vagy az URL-ből származó kezdeti szűrőket.
  @override
  void initState() {
    super.initState();
    // Mentett vagy URL paraméterekből származó szűrők betöltése
    _loadSavedFilters();
    _loadCategories();
    _loadSciences();
    _loadTags();
  }

  /// Betölti a mentett szűrőket vagy az URL paraméterekből származó kezdeti szűrőket.
  void _loadSavedFilters() {
    // Először megnézzük, hogy vannak-e mentett szűrők a FilterStorage-ban
    if (FilterStorage.searchText != null ||
        FilterStorage.status != null ||
        FilterStorage.category != null ||
        FilterStorage.science != null ||
        FilterStorage.tag != null ||
        FilterStorage.type != null) {
      // Ha vannak mentett szűrők, akkor azokat használjuk
      setState(() {
        _searchText = FilterStorage.searchText ?? '';
        _searchController.text = _searchText;
        _selectedStatus = FilterStorage.status;
        _selectedCategory = FilterStorage.category;
        _selectedScience = FilterStorage.science;
        _selectedTag = FilterStorage.tag;
        _selectedType = FilterStorage.type;
      });
    } else {
      // Ha nincsenek mentett szűrők, akkor az URL paramétereket használjuk
      setState(() {
        _searchText = widget.initialSearch ?? '';
        _searchController.text = _searchText;
        _selectedStatus = widget.initialStatus;
        _selectedCategory = widget.initialCategory;
        _selectedScience = widget.initialScience;
        _selectedTag = widget.initialTag;
        _selectedType = widget.initialType;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Betölti a kategóriákat a Firestore `categories` kollekciójából.
  Future<void> _loadCategories() async {
    final snapshot =
        await FirebaseConfig.firestore.collection('categories').get();
    // A `setState` frissíti a widget állapotát a betöltött adatokkal,
    // ami újraépíti a UI-t, és a `Filters` widget megkapja a kategóriákat.
    setState(() {
      _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  /// Betölti a címkéket a Firestore `tags` kollekciójából.
  Future<void> _loadSciences() async {
    final snapshot =
        await FirebaseConfig.firestore.collection('sciences').get();
    setState(() {
      _sciences = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  Future<void> _loadTags() async {
    final notesSnapshot =
        await FirebaseConfig.firestore.collection('notes').get();
    final allTags =
        <String>{}; // Set-et használunk a duplikátumok automatikus kezelésére

    for (final doc in notesSnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('tags') && data['tags'] is List) {
        final tags = List<String>.from(data['tags']);
        allTags.addAll(tags);
      }
    }

    if (mounted) {
      setState(() {
        _tags = allTags.toList()
          ..sort(); // Opcionális: ABC sorrendbe rendezzük a listát
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
    // Ha a controller értéke eltér, frissítjük
    if (_searchController.text != value) {
      _searchController.text = value;
    }
    // Menti a keresési feltételt a FilterStorage-ba
    FilterStorage.searchText = value.isNotEmpty ? value : null;
    _pushFiltersToUrl();
  }

  /// Frissíti a kiválasztott státuszt a `Filters` widgetből.
  void _onStatusChanged(String? value) {
    setState(() {
      _selectedStatus = value;
    });
    // Menti a státusz szűrőt a FilterStorage-ba
    FilterStorage.status = value;
    _pushFiltersToUrl();
  }

  /// Frissíti a kiválasztott kategóriát a `Filters` widgetből.
  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value;
    });
    // Menti a kategória szűrőt a FilterStorage-ba
    FilterStorage.category = value;
    _pushFiltersToUrl();
  }

  /// Frissíti a kiválasztott tudományt.
  void _onScienceChanged(String? value) {
    setState(() {
      _selectedScience = value;
    });
    // Menti a tudomány szűrőt a FilterStorage-ba
    FilterStorage.science = value;
    _pushFiltersToUrl();
  }

  /// Frissíti a kiválasztott címkét a `Filters` widgetből.
  void _onTagChanged(String? value) {
    setState(() => _selectedTag = value);
    // Menti a címke szűrőt a FilterStorage-ba
    FilterStorage.tag = value;
    _pushFiltersToUrl();
  }

  /// Frissíti a kiválasztott típust.
  void _onTypeChanged(String? value) {
    setState(() => _selectedType = value);
    // Menti a típus szűrőt a FilterStorage-ba
    FilterStorage.type = value;
    _pushFiltersToUrl();
  }

  /// Törli az összes aktív szűrőt.
  void _onClearFilters() {
    setState(() {
      _searchText = '';
      _searchController.clear();
      _selectedStatus = null;
      _selectedCategory = null;
      _selectedScience = null;
      _selectedTag = null;
      _selectedType = null;
    });
    // Törli a szűrőket a FilterStorage-ból is
    FilterStorage.clearFilters();
    _pushFiltersToUrl();
  }

  void _pushFiltersToUrl() {
    final params = <String, String>{};
    void put(String key, String? val) {
      if (val != null && val.isNotEmpty) params[key] = val;
    }

    put('q', _searchText);
    put('status', _selectedStatus);
    put('category', _selectedCategory);
    put('science', _selectedScience);
    put('tag', _selectedTag);
    put('type', _selectedType);
    final uri =
        Uri(path: '/notes', queryParameters: params.isEmpty ? null : params);
    // go_router: go() replaces current route without adding history entry
    GoRouter.of(context).go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    Widget buildContent({required bool showSideFilters}) {
      return Row(
        children: [
          if (showSideFilters)
            SizedBox(
              width: 320,
              child: Card(
                margin: const EdgeInsets.fromLTRB(12, 10, 8, 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Szűrők',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Filters(
                          categories: _categories,
                          sciences: _sciences,
                          tags: _tags,
                          selectedStatus: _selectedStatus,
                          selectedCategory: _selectedCategory,
                          selectedScience: _selectedScience,
                          selectedTag: _selectedTag,
                          selectedType: _selectedType,
                          onStatusChanged: _onStatusChanged,
                          onCategoryChanged: _onCategoryChanged,
                          onScienceChanged: _onScienceChanged,
                          onTagChanged: _onTagChanged,
                          onTypeChanged: _onTypeChanged,
                          onClearFilters: _onClearFilters,
                          vertical: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Header(
                  onSearchChanged: _onSearchChanged,
                ),
                Expanded(
                  child: NoteCardGrid(
                    searchText: _searchText,
                    selectedStatus: _selectedStatus,
                    selectedCategory: _selectedCategory,
                    selectedScience: _selectedScience,
                    selectedTag: _selectedTag,
                    selectedType: _selectedType,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 1200) {
          // Desktop: kétpaneles elrendezés
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 249, 250, 251),
            body: Row(
              children: [
                Sidebar(
                  selectedMenu: 'notes',
                  extraPanel: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Filters(
                        categories: _categories,
                        sciences: _sciences,
                        tags: _tags,
                        selectedStatus: _selectedStatus,
                        selectedCategory: _selectedCategory,
                        selectedScience: _selectedScience,
                        selectedTag: _selectedTag,
                        selectedType: _selectedType,
                        onStatusChanged: _onStatusChanged,
                        onCategoryChanged: _onCategoryChanged,
                        onScienceChanged: _onScienceChanged,
                        onTagChanged: _onTagChanged,
                        onTypeChanged: _onTypeChanged,
                        onClearFilters: _onClearFilters,
                        vertical: true,
                        showStatus: false,
                        showType: false,
                      ),
                    ),
                  ),
                ),
                Expanded(child: buildContent(showSideFilters: false)),
              ],
            ),
          );
        }

        // Tablet/Mobil: Drawer + AppBar menü, és a szűrők a drawer-ben
        return Scaffold(
          appBar: AppBar(
            title: const Text('Jegyzetek'),
          ),
          drawer: Drawer(
            child: SafeArea(
              child: Sidebar(
                selectedMenu: 'notes',
                extraPanel: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Filters(
                      categories: _categories,
                      sciences: _sciences,
                      tags: _tags,
                      selectedStatus: _selectedStatus,
                      selectedCategory: _selectedCategory,
                      selectedScience: _selectedScience,
                      selectedTag: _selectedTag,
                      selectedType: _selectedType,
                      onStatusChanged: _onStatusChanged,
                      onCategoryChanged: _onCategoryChanged,
                      onScienceChanged: _onScienceChanged,
                      onTagChanged: _onTagChanged,
                      onTypeChanged: _onTypeChanged,
                      onClearFilters: _onClearFilters,
                      vertical: true,
                      showStatus: false,
                      showType: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: buildContent(showSideFilters: false),
          ),
          backgroundColor: const Color.fromARGB(255, 249, 250, 251),
        );
      },
    );
  }
}

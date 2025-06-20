import 'package:flutter/material.dart';

/// A jegyzetek listájának szűrésére szolgáló vezérlőket tartalmazó widget.
///
/// Ez egy `StatefulWidget`, mert a legördülő menüknek van egy belső állapota
/// (az aktuálisan kiválasztott érték), amelyet a felhasználó közvetlenül
/// módosíthat. Azonban a szűrési logika nagy része a szülő widgetben
/// (`NoteListScreen`) található; ez a widget a `callback` függvényeken
/// keresztül csak értesíti a szülőt a változásokról.
class Filters extends StatefulWidget {
  // A szülő widgettől kapott adatok és callback függvények.
  final List<String> categories; // A választható kategóriák listája.
  final List<String> tags; // A választható címkék listája.
  final String? selectedStatus; // A szülő által meghatározott aktív státusz szűrő.
  final String? selectedCategory; // Az aktív kategória szűrő.
  final String? selectedTag; // Az aktív címke szűrő.
  final ValueChanged<String?> onStatusChanged; // Callback a státusz változásakor.
  final ValueChanged<String?> onCategoryChanged; // Callback a kategória változásakor.
  final ValueChanged<String?> onTagChanged; // Callback a címke változásakor.
  final VoidCallback onClearFilters; // Callback a szűrők törlésekor.

  const Filters({
    super.key,
    required this.categories,
    required this.tags,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.selectedTag,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onTagChanged,
    required this.onClearFilters,
  });

  @override
  State<Filters> createState() => _FiltersState();
}

/// A `Filters` widget állapotát kezelő osztály.
class _FiltersState extends State<Filters> {
  // Belső állapotváltozók a legördülő menük aktuális értékének tárolására.
  // Erre azért van szükség, hogy a UI azonnal frissüljön, amikor a
  // felhasználó választ, anélkül, hogy a teljes szülő widgetet újra kellene építeni.
  String? _status;
  String? _category;
  String? _tag;

  /// A widget inicializálásakor lefutó metódus.
  @override
  void initState() {
    super.initState();
    // A belső állapotot inicializálja a szülőtől kapott értékekkel.
    _status = widget.selectedStatus;
    _category = widget.selectedCategory;
    _tag = widget.selectedTag;
  }

  /// Akkor hívódik meg, amikor a szülő widget frissül és új paramétereket ad át.
  ///
  /// Erre azért van szükség, hogy a belső állapot szinkronban maradjon a szülő
  /// állapotával, például amikor a szülő "kívülről" (pl. egy "Szűrők törlése"
  /// gombbal) megváltoztatja a szűrőket.
  @override
  void didUpdateWidget(covariant Filters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStatus != oldWidget.selectedStatus) {
      _status = widget.selectedStatus;
    }
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      _category = widget.selectedCategory;
    }
    if (widget.selectedTag != oldWidget.selectedTag) {
      _tag = widget.selectedTag;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A szűrősáv egy sorban (`Row`) rendezi el a legördülő menüket és a törlés gombot.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // A `Theme` widget segítségével helyileg felülírjuk a legördülő menük
          // néhány vizuális tulajdonságát (pl. háttérszín), hogy jobban illeszkedjenek a designba.
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            // Státusz szűrő legördülő menü.
            child: DropdownButton<String>(
              hint: const Text(
                'Státusz',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              value: _status, // A menü aktuális értéke a belső állapotból jön.
              // A választható elemek listája egy fix listából generálódik.
              items: ['Draft', 'Published', 'Archived']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Container(
                          color: Colors.transparent,
                          child: Text(status, style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
              // Ez a builder határozza meg, hogyan nézzen ki a kiválasztott elem a menüben.
              selectedItemBuilder: (context) {
                return ['Draft', 'Published', 'Archived']
                    .map((status) => Text(status, style: const TextStyle(fontSize: 12, backgroundColor: Colors.transparent)))
                    .toList();
              },
              // A `onChanged` esemény két dolgot csinál:
              // 1. Frissíti a belső állapotot (`_status`) a `setState`-tel, hogy a UI azonnal mutassa a változást.
              // 2. Meghívja a szülő `onStatusChanged` callback függvényét, hogy a szülő is tudomást szerezzen a változásról.
              onChanged: (value) {
                setState(() => _status = value);
                widget.onStatusChanged(value);
              },
            ),
          ),
          const SizedBox(width: 16),
          // Kategória szűrő (a felépítése megegyezik a státusz szűrőével).
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              hint: const Text(
                'Kategória',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              value: _category,
              // A választható elemek listája a szülőtől kapott `widget.categories`-ből generálódik.
              items: widget.categories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Container(
                          color: Colors.transparent,
                          child: Text(category, style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
              selectedItemBuilder: (context) {
                return widget.categories
                    .map((category) => Text(category, style: const TextStyle(fontSize: 12, backgroundColor: Colors.transparent)))
                    .toList();
              },
              onChanged: (value) {
                setState(() => _category = value);
                widget.onCategoryChanged(value);
              },
            ),
          ),
          const SizedBox(width: 16),
          // Címke szűrő (a felépítése megegyezik a státusz szűrőével).
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              hint: const Text(
                'Címke',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              value: _tag,
              // A választható elemek listája a szülőtől kapott `widget.tags`-ből generálódik.
              items: widget.tags
                  .map((tag) => DropdownMenuItem(
                        value: tag,
                        child: Container(
                          color: Colors.transparent,
                          child: Text(tag, style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
              selectedItemBuilder: (context) {
                return widget.tags
                    .map((tag) => Text(tag, style: const TextStyle(fontSize: 12, backgroundColor: Colors.transparent)))
                    .toList();
              },
              onChanged: (value) {
                setState(() => _tag = value);
                widget.onTagChanged(value);
              },
            ),
          ),
          const SizedBox(width: 16),
          // Szűrők törlése gomb.
          TextButton(
            onPressed: () {
              // A gomb lenyomásakor a belső állapotot is és a szülő állapotát is törli.
              setState(() {
                _status = null;
                _category = null;
                _tag = null;
              });
              widget.onClearFilters();
            },
            child: const Text('Szűrők törlése'),
          ),
        ],
      ),
    );
  }
}

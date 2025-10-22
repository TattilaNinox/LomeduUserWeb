import 'package:flutter/material.dart';

class Filters extends StatefulWidget {
  final List<String> categories;
  final List<String> sciences;
  final List<String> tags;
  final String? selectedStatus;
  final String? selectedCategory;
  final String? selectedTag;
  final String? selectedScience;
  final String? selectedType;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onScienceChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onClearFilters;
  final bool vertical;
  final bool showStatus;
  final bool showType;

  const Filters({
    super.key,
    required this.categories,
    required this.sciences,
    required this.tags,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.selectedTag,
    required this.selectedScience,
    required this.selectedType,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onScienceChanged,
    required this.onTagChanged,
    required this.onTypeChanged,
    required this.onClearFilters,
    this.vertical = false,
    this.showStatus = false,
    this.showType = true,
  });

  @override
  State<Filters> createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  String? _status;
  String? _category;
  String? _science;
  String? _tag;
  String? _type;

  static const _noteTypes = [
    'text',
    'interactive',
    'dynamic_quiz',
    'dynamic_quiz_dual',
    'deck',
    'source'
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _category = widget.selectedCategory;
    _science = widget.selectedScience;
    _tag = widget.selectedTag;
    _type = widget.selectedType;
  }

  @override
  void didUpdateWidget(covariant Filters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStatus != oldWidget.selectedStatus) {
      _status = widget.selectedStatus;
    }
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      _category = widget.selectedCategory;
    }
    if (widget.selectedScience != oldWidget.selectedScience) {
      _science = widget.selectedScience;
    }
    if (widget.selectedTag != oldWidget.selectedTag) {
      _tag = widget.selectedTag;
    }
    if (widget.selectedType != oldWidget.selectedType) {
      _type = widget.selectedType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final outerPadding = widget.vertical
        ? const EdgeInsets.all(8.0)
        : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
    final gap =
        widget.vertical ? const SizedBox(height: 8) : const SizedBox(width: 16);

    final List<Widget> children = [];
    void add(Widget w) {
      if (children.isNotEmpty) children.add(gap);
      children.add(w);
    }

    if (widget.showType) {
      add(_buildDropdown<String>(
        hint: 'Típus',
        value: _type,
        items: _noteTypes,
        onChanged: (v) {
          setState(() => _type = v);
          widget.onTypeChanged(v);
        },
        isExpanded: widget.vertical,
      ));
    }

    if (widget.showStatus) {
      add(_buildDropdown<String>(
        hint: 'Státusz',
        value: _status,
        items: const ['Draft', 'Published', 'Archived'],
        onChanged: (v) {
          setState(() => _status = v);
          widget.onStatusChanged(v);
        },
        isExpanded: widget.vertical,
      ));
    }

    add(_buildDropdown<String>(
      hint: 'Kategória',
      value: _category,
      items: widget.categories,
      onChanged: (v) {
        setState(() => _category = v);
        widget.onCategoryChanged(v);
      },
      isExpanded: widget.vertical,
    ));

    // Tudomány szűrő - fix értékkel, de automatikusan a felhasználó tudományára beállítva
    add(Opacity(
      opacity: 0.6,
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: DropdownButton<String>(
          hint: const Text('Tudomány',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          value: _science,
          isExpanded: widget.vertical,
          items: widget.sciences.map((science) {
            return DropdownMenuItem<String>(
              value: science,
              child: Text(science, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged:
              null, // inaktív, mert automatikusan a felhasználó tudományára van állítva
        ),
      ),
    ));

    add(_buildDropdown<String>(
      hint: 'Címke',
      value: _tag,
      items: widget.tags,
      onChanged: (v) {
        setState(() => _tag = v);
        widget.onTagChanged(v);
      },
      isExpanded: widget.vertical,
    ));

    add(Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          setState(() {
            _status = null;
            _category = null;
            _tag = null;
            _type = null;
            // _science NEM törlődik, mert fix a felhasználó tudományára
          });
          widget.onClearFilters();
          widget.onTypeChanged(null);
          // widget.onScienceChanged(null); <- NEM hívjuk meg, hogy a tudomány megmaradjon
        },
        child: const Text('Szűrők törlése'),
      ),
    ));

    return Padding(
      padding: outerPadding,
      child: widget.vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)
          : Row(children: children),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool isExpanded = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.white,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: DropdownButton<T>(
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        value: value,
        isExpanded: isExpanded,
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child:
                      Text(e.toString(), style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
        selectedItemBuilder: (context) => items
            .map(
                (e) => Text(e.toString(), style: const TextStyle(fontSize: 12)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

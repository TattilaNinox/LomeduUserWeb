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
  });

  @override
  State<Filters> createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  String? _status;
  String? _category;
  String? _tag;
  String? _science;
  String? _type;

  static const _noteTypes = ['text', 'interactive', 'dynamic_quiz', 'dynamic_quiz_dual', 'deck', 'source'];

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _category = widget.selectedCategory;
    _tag = widget.selectedTag;
    _science = widget.selectedScience;
    _type = widget.selectedType;
  }

  @override
  void didUpdateWidget(covariant Filters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStatus != oldWidget.selectedStatus) _status = widget.selectedStatus;
    if (widget.selectedCategory != oldWidget.selectedCategory) _category = widget.selectedCategory;
    if (widget.selectedTag != oldWidget.selectedTag) _tag = widget.selectedTag;
    if (widget.selectedScience != oldWidget.selectedScience) _science = widget.selectedScience;
    if (widget.selectedType != oldWidget.selectedType) _type = widget.selectedType;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Type filter
          _buildDropdown<String>(
            hint: 'Típus',
            value: _type,
            items: _noteTypes,
            onChanged: (v) {
              setState(() => _type = v);
              widget.onTypeChanged(v);
            },
          ),
          const SizedBox(width: 16),
          // Status filter
          _buildDropdown<String>(
            hint: 'Státusz',
            value: _status,
            items: ['Draft', 'Published', 'Archived'],
            onChanged: (v) {
              setState(() => _status = v);
              widget.onStatusChanged(v);
            },
          ),
          const SizedBox(width: 16),
          _buildDropdown<String>(
            hint: 'Kategória',
            value: _category,
            items: widget.categories,
            onChanged: (v) {
              setState(() => _category = v);
              widget.onCategoryChanged(v);
            },
          ),
          const SizedBox(width: 16),
          _buildDropdown<String>(
            hint: 'Tudomány',
            value: _science,
            items: widget.sciences,
            onChanged: (v) {
              setState(() => _science = v);
              widget.onScienceChanged(v);
            },
          ),
          const SizedBox(width: 16),
          _buildDropdown<String>(
            hint: 'Címke',
            value: _tag,
            items: widget.tags,
            onChanged: (v) {
              setState(() => _tag = v);
              widget.onTagChanged(v);
            },
          ),
          const SizedBox(width: 16),
          TextButton(onPressed: () {
            setState(() {
              _status = null;
              _category = null;
              _tag = null;
              _science = null;
              _type = null;
            });
            widget.onClearFilters();
            widget.onTypeChanged(null);
            widget.onScienceChanged(null);
          }, child: const Text('Szűrők törlése')),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.white,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: DropdownButton<T>(
        hint: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        value: value,
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString(), style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
        selectedItemBuilder: (context) => items
            .map((e) => Text(e.toString(), style: const TextStyle(fontSize: 12)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
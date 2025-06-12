import 'package:flutter/material.dart';

class Filters extends StatefulWidget {
  final List<String> categories;
  final List<String> tags;
  final String? selectedStatus;
  final String? selectedCategory;
  final String? selectedTag;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTagChanged;
  final VoidCallback onClearFilters;

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

class _FiltersState extends State<Filters> {
  String? _status;
  String? _category;
  String? _tag;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _category = widget.selectedCategory;
    _tag = widget.selectedTag;
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
    if (widget.selectedTag != oldWidget.selectedTag) {
      _tag = widget.selectedTag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              hint: const Text(
                'Státusz',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              value: _status,
              items: ['Draft', 'Published', 'Archived']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Container(
                          color: Colors.transparent,
                          child: Text(status, style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
              selectedItemBuilder: (context) {
                return ['Draft', 'Published', 'Archived']
                    .map((status) => Text(status, style: const TextStyle(fontSize: 12, backgroundColor: Colors.transparent)))
                    .toList();
              },
              onChanged: (value) {
                setState(() => _status = value);
                widget.onStatusChanged(value);
              },
            ),
          ),
          const SizedBox(width: 16),
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
          TextButton(
            onPressed: () {
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

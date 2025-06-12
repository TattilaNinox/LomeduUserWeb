import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/sidebar.dart';
import '../widgets/header.dart';
import '../widgets/filters.dart';
import '../widgets/note_table.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  String _searchText = '';
  String? _selectedStatus;
  String? _selectedCategory;
  String? _selectedTag;

  List<String> _categories = [];
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTags();
  }

  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    setState(() {
      _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  Future<void> _loadTags() async {
    final snapshot = await FirebaseFirestore.instance.collection('tags').get();
    setState(() {
      _tags = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
    });
  }

  void _onStatusChanged(String? value) {
    setState(() {
      _selectedStatus = value;
    });
  }

  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value;
    });
  }

  void _onTagChanged(String? value) {
    setState(() {
      _selectedTag = value;
    });
  }

  void _onClearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedCategory = null;
      _selectedTag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 250, 251),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'notes'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Header(
                  onSearchChanged: _onSearchChanged,
                ),
                Filters(
                  categories: _categories,
                  tags: _tags,
                  selectedStatus: _selectedStatus,
                  selectedCategory: _selectedCategory,
                  selectedTag: _selectedTag,
                  onStatusChanged: _onStatusChanged,
                  onCategoryChanged: _onCategoryChanged,
                  onTagChanged: _onTagChanged,
                  onClearFilters: _onClearFilters,
                ),
                NoteTable(
                  searchText: _searchText,
                  selectedStatus: _selectedStatus,
                  selectedCategory: _selectedCategory,
                  selectedTag: _selectedTag,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

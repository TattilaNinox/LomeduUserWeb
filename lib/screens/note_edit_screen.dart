import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:video_player/video_player.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:html/parser.dart' show parse;
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import '../widgets/sidebar.dart';

class NoteEditScreen extends StatefulWidget {
  final String noteId;

  const NoteEditScreen({super.key, required this.noteId});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _htmlContentController = TextEditingController();
  String? _selectedCategory;
  List<String> _tags = [];
  final _tagController = TextEditingController();
  String? _noteType;

  Map<String, dynamic>? _selectedMp3File;
  Map<String, dynamic>? _selectedVideoFile;
  VideoPlayerController? _videoController;

  List<String> _categories = [];
  late TabController _tabController;
  final ValueNotifier<double> _editorFontSize = ValueNotifier<double>(9.0);

  late final String _previewViewId;
  final web.HTMLIFrameElement _previewIframeElement = web.HTMLIFrameElement();
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _previewViewId = 'note-edit-preview-iframe-${widget.noteId}';

    _previewIframeElement
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none';
    
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
        _previewViewId, (int viewId) => _previewIframeElement);

    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _htmlContentController.dispose();
    _tagController.dispose();
    _videoController?.dispose();
    _tabController.dispose();
    _editorFontSize.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      await _loadCategories();
      await _loadNoteData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Hiba a kezdeti adatok betöltésekor: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    if (mounted) {
      _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    }
  }

  Future<void> _loadNoteData() async {
    final doc = await FirebaseFirestore.instance.collection('notes').doc(widget.noteId).get();
    
    if (!doc.exists) {
      throw Exception('A jegyzet nem található.');
    }

    if (mounted) {
      final data = doc.data()!;
      _titleController.text = data['title'] ?? '';
      _selectedCategory = data['category'];
      _tags = List<String>.from(data['tags'] ?? []);
      _noteType = data['type'];

      if (data.containsKey('audioUrl')) {
        _selectedMp3File = {'name': 'Meglévő hangfájl', 'url': data['audioUrl']};
      }
      if (data.containsKey('videoUrl')) {
        _selectedVideoFile = {'name': 'Meglévő videófájl', 'url': data['videoUrl']};
      }

      final pages = data['pages'] as List<dynamic>? ?? [];
      final content = pages.isNotEmpty ? pages.first as String : '';
      
      _htmlContentController.text = content;
    }
  }
  
  Future<void> _updateNote() async {
    if (_titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A cím és a kategória megadása kötelező!')),
      );
      return;
    }
    
    if (_htmlContentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A tartalom nem lehet üres!')),
      );
      return;
    }
    
    setState(() => _isSaving = true);

    try {
      for (final tag in _tags) {
        FirebaseFirestore.instance.collection('tags').doc(tag).set({'name': tag});
      }

      final Map<String, dynamic> noteData = {
        'title': _titleController.text,
        'category': _selectedCategory,
        'tags': _tags,
        'pages': [_htmlContentController.text],
        'modified': Timestamp.now(),
        'type': _noteType,
      };

      if (isFileValid(_selectedMp3File) && _selectedMp3File!['bytes'] != null) {
        final mp3Ref = FirebaseStorage.instance
            .ref('notes/${widget.noteId}/${_selectedMp3File!['name']}');
        await mp3Ref.putData(
            Uint8List.fromList(_selectedMp3File!['bytes'] as List<int>));
        noteData['audioUrl'] = await mp3Ref.getDownloadURL();
      }

      if (isFileValid(_selectedVideoFile) && _selectedVideoFile!['bytes'] != null) {
        final videoRef = FirebaseStorage.instance
            .ref('notes/${widget.noteId}/${_selectedVideoFile!['name']}');
        await videoRef.putData(
            Uint8List.fromList(_selectedVideoFile!['bytes'] as List<int>));
        noteData['videoUrl'] = await videoRef.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('notes')
          .doc(widget.noteId)
          .update(noteData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jegyzet sikeresen frissítve!')),
        );
        context.go('/notes');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a mentés során: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))));
    }
    
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 250, 251),
      appBar: AppBar(
        title: Text('"${_titleController.text}" szerkesztése'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/notes'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Mentés'),
              onPressed: _isSaving ? null : _updateNote,
            ),
          )
        ],
      ),
      body: Row(
        children: [
          Sidebar(selectedMenu: _noteType == 'interactive' ? 'interactive_notes' : 'notes'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bal oldali, fő tartalom
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(_titleController, 'Jegyzet címe'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: _buildCategoryDropdown(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildEditorAndPreview(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Jobb oldali sáv
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTagsSection(),
                            const SizedBox(height: 24),
                            _buildFileUploadSection(),
                          ],
                        ),
                      ),
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

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
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
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildEditorAndPreview() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Szerkesztő'),
                    Tab(text: 'Előnézet'),
                  ],
                  onTap: (index) {
                    if (index == 1) { // Preview tab
                      final htmlContent = _htmlContentController.text;
                      if (htmlContent.isNotEmpty) {
                        if (parse(htmlContent).documentElement == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Figyelem: A HTML kód érvénytelennek tűnik.'),
                                backgroundColor: Colors.orange),
                          );
                          _tabController.index = 0; // Visszaváltás
                          return;
                        }
                        setState(() {
                          _previewIframeElement.src = 'data:text/html;charset=utf-8,${Uri.encodeComponent(htmlContent)}';
                          _showPreview = true;
                        });
                      } else {
                        setState(() {
                          _showPreview = false;
                        });
                      }
                    } else {
                      setState(() {
                        _showPreview = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              ValueListenableBuilder<double>(
                valueListenable: _editorFontSize,
                builder: (context, fontSize, child) {
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (fontSize > 8.0) {
                            _editorFontSize.value--;
                          }
                        },
                        tooltip: 'Betűméret csökkentése',
                      ),
                      Text('${fontSize.toInt()}pt'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (fontSize < 24.0) {
                            _editorFontSize.value++;
                          }
                        },
                        tooltip: 'Betűméret növelése',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Editor
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SizedBox(
                    height: 300,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _editorFontSize,
                      builder: (context, fontSize, child) {
                        return TextField(
                          controller: _htmlContentController,
                          onChanged: (value) {
                            if (_tabController.index == 1) {
                              setState(() {
                                _previewIframeElement.src = 'data:text/html;charset=utf-8,${Uri.encodeComponent(value)}';
                              });
                            }
                          },
                          style: TextStyle(fontSize: fontSize, fontFamily: 'monospace'),
                          maxLines: 15,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: 'Írd ide a HTML tartalmat...',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        );
                      }
                    ),
                  ),
                ),
                // Preview
                _showPreview
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!)
                          ),
                          child: HtmlElementView(viewType: _previewViewId)
                        ),
                      )
                    : const Center(
                        child: Text(
                            'Az előnézethez írj be HTML tartalmat és válts fület.')),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Címkék', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _tags.map((tag) => Chip(
            label: Text(tag),
            onDeleted: () {
              setState(() => _tags.remove(tag));
            },
          )).toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            labelText: 'Új címke',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (_tagController.text.isNotEmpty && !_tags.contains(_tagController.text)) {
                  setState(() {
                    _tags.add(_tagController.text);
                    _tagController.clear();
                  });
                }
              },
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty && !_tags.contains(value)) {
              setState(() {
                _tags.add(value);
                _tagController.clear();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Fájlok', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildFileUploadButton(
          label: 'MP3 Csere',
          icon: Icons.audiotrack,
          file: _selectedMp3File,
          onPressed: _pickMp3File,
        ),
        const SizedBox(height: 12),
        _buildFileUploadButton(
          label: 'Videó Csere',
          icon: Icons.videocam,
          file: _selectedVideoFile,
          onPressed: _pickVideoFile,
        ),
         if (_selectedVideoFile != null && _selectedVideoFile!['path'] != null && !kIsWeb)
           Padding(
             padding: const EdgeInsets.only(top: 8.0),
             child: AspectRatio(
               aspectRatio: _videoController!.value.aspectRatio,
               child: VideoPlayer(_videoController!),
             ),
           )
      ],
    );
  }

  Widget _buildFileUploadButton({
    required String label,
    required IconData icon,
    required Map<String, dynamic>? file,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (file != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Kiválasztva: ${file['name']}',
              style: const TextStyle(fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  bool isFileValid(Map<String, dynamic>? file) {
    return file != null && file['name'] != null;
  }

  Future<void> _pickMp3File() async {
    const typeGroup = XTypeGroup(label: 'MP3', extensions: ['mp3']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A hangfájl mérete nem haladhatja meg az 5 MB-ot!')),
        );
        return;
      }
      setState(() => _selectedMp3File = {
            'name': file.name, 'size': bytes.length, 'bytes': bytes
      });
    }
  }

  Future<void> _pickVideoFile() async {
    const typeGroup = XTypeGroup(label: 'Video', extensions: ['mp4', 'mov', 'avi']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      final bytes = await file.readAsBytes();
       if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A videófájl mérete nem haladhatja meg az 5 MB-ot!')),
        );
        return;
      }
      setState(() {
        _selectedVideoFile = {'name': file.name, 'size': bytes.length, 'bytes': bytes, 'path': file.path};
        _videoController?.dispose();
        if (!kIsWeb) {
          _videoController = VideoPlayerController.file(File(file.path))..initialize().then((_) => setState(() {}));
        }
      });
    }
  }
} 
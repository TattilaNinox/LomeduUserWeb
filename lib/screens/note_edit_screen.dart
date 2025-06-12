import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:video_player/video_player.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:html' as html;

import '../widgets/sidebar.dart';

class NoteEditScreen extends StatefulWidget {
  final String noteId;

  const NoteEditScreen({super.key, required this.noteId});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  bool _isLoading = true;
  String? _error;

  final _titleController = TextEditingController();
  final _htmlContentController = TextEditingController();
  String? _selectedCategory;
  List<String> _tags = [];
  final _tagController = TextEditingController();

  Map<String, dynamic>? _selectedMp3File;
  Map<String, dynamic>? _selectedVideoFile;
  VideoPlayerController? _videoController;

  List<String> _categories = [];
  WebViewController? _previewWebViewController;
  bool _showPreview = false;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    _titleController.dispose();
    _htmlContentController.dispose();
    _tagController.dispose();
    _videoController?.dispose();
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

    try {
      String content = _htmlContentController.text;

      if (content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A tartalom nem lehet üres!')),
        );
        return;
      }
      
      for (final tag in _tags) {
        FirebaseFirestore.instance.collection('tags').doc(tag).set({'name': tag});
      }

      final Map<String, dynamic> noteData = {
        'title': _titleController.text,
        'category': _selectedCategory,
        'tags': _tags,
        'pages': [content],
        'modified': Timestamp.now(),
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
              icon: const Icon(Icons.save),
              label: const Text('Mentés'),
              onPressed: _updateNote,
            ),
          )
        ],
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'notes'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Jegyzet címe',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
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
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Tartalom (HTML)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _htmlContentController,
                        decoration: const InputDecoration(
                          labelText: 'HTML forráskód',
                          border: OutlineInputBorder(),
                           alignLabelWithHint: true,
                        ),
                        style: const TextStyle(fontSize: 9.0),
                        maxLines: 25,
                      ),
                       const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('Előnézet'),
                        onPressed: () {
                          final htmlContent = _htmlContentController.text;
                          if (mounted) {
                            setState(() {
                              if (_blobUrl != null) {
                                html.Url.revokeObjectUrl(_blobUrl!);
                              }
                              final blob = html.Blob([htmlContent], 'text/html');
                              _blobUrl = html.Url.createObjectUrlFromBlob(blob);
                              _previewWebViewController = WebViewController()
                                ..loadRequest(Uri.parse(_blobUrl!));
                              _showPreview = true;
                            });
                          }
                        },
                      ),
                       if (_showPreview && _previewWebViewController != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          height: 500,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: WebViewWidget(
                            controller: _previewWebViewController!,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildTagEditor(),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickMp3File,
                            icon: const Icon(Icons.audiotrack),
                            label: const Text('MP3 Csere'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickVideoFile,
                            icon: const Icon(Icons.video_call),
                            label: const Text('Videó Csere'),
                          ),
                        ],
                      ),
                      _buildFileInfoTile(_selectedMp3File, 'mp3'),
                      _buildFileInfoTile(_selectedVideoFile, 'video'),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Címkék', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: _tags.map((tag) => Chip(
            label: Text(tag),
            onDeleted: () {
              setState(() {
                _tags.remove(tag);
              });
            },
          )).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            labelText: 'Új címke hozzáadása',
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

  Widget _buildFileInfoTile(Map<String, dynamic>? file, String type) {
    if (file == null) return const SizedBox.shrink();

    IconData icon = type == 'mp3' ? Icons.music_note : Icons.movie;
    String sizeInfo = file.containsKey('size') ? '${(file['size'] / 1024).toStringAsFixed(2)} KB' : 'Már fel van töltve';

    return Column(
      children: [
        const SizedBox(height: 16),
        ListTile(
          leading: Icon(icon),
          title: Text(file['name']),
          subtitle: Text(sizeInfo),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              if (type == 'mp3') {
                _selectedMp3File = null;
              } else {
                _selectedVideoFile = null;
                _videoController?.dispose();
                _videoController = null;
              }
            }),
          ),
        ),
        if (type == 'video' && _videoController != null && _videoController!.value.isInitialized)
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
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
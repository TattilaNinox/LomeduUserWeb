import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'package:video_player/video_player.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' show parse;
import 'dart:html' as html;

import '../widgets/sidebar.dart';
import '../widgets/header.dart';

class InteractiveNoteCreateScreen extends StatefulWidget {
  const InteractiveNoteCreateScreen({super.key});

  @override
  State<InteractiveNoteCreateScreen> createState() =>
      _InteractiveNoteCreateScreenState();
}

class _InteractiveNoteCreateScreenState
    extends State<InteractiveNoteCreateScreen> {
  final _titleController = TextEditingController();
  final _htmlContentController = TextEditingController();
  String? _selectedCategory;
  Map<String, dynamic>? _selectedMp3File;
  Map<String, dynamic>? _selectedVideoFile;
  bool _isUploading = false;
  List<String> _categories = [];
  VideoPlayerController? _videoController;
  List<String> _tags = [];
  final _tagController = TextEditingController();
  WebViewController? _previewWebViewController;
  bool _showPreview = false;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    _titleController.dispose();
    _htmlContentController.dispose();
    _videoController?.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('categories').get();
    if (mounted) {
      setState(() {
        _categories =
            snapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    }
  }

  bool isFileValid(Map<String, dynamic>? file) {
    return file != null &&
        file['bytes'] != null &&
        (file['bytes'] as List<int>).isNotEmpty;
  }

  Future<void> _pickMp3File() async {
    final typeGroup = XTypeGroup(
      label: 'MP3',
      extensions: const ['mp3'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        setState(() => _selectedMp3File = {
              'name': file.name,
              'size': bytes.length,
              'bytes': bytes,
            });
      } else {
        debugPrint(
            'Az MP3 fájl nem tartalmaz adatot vagy nem sikerült betölteni.');
      }
    }
  }

  Future<void> _pickVideoFile() async {
    final typeGroup = XTypeGroup(
      label: 'Video',
      extensions: const ['mp4', 'mov', 'avi'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        if (bytes.length > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('A videófájl mérete nem haladhatja meg az 5 MB-ot!')),
          );
          return;
        }
        setState(() => _selectedVideoFile = {
              'name': file.name,
              'size': bytes.length,
              'bytes': bytes,
              'path': file.path,
            });
        _videoController?.dispose();
        if (!kIsWeb) {
          _videoController = VideoPlayerController.file(File(file.path));
          await _videoController!.initialize();
          if (!mounted) return;
          setState(() {});
        }
      } else {
        debugPrint(
            'A videófájl nem tartalmaz adatot vagy nem sikerült betölteni.');
      }
    }
  }

  Future<void> _uploadNote() async {
    final htmlContent = _htmlContentController.text;

    if (_titleController.text.isEmpty ||
        _selectedCategory == null ||
        htmlContent.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A cím, kategória és a tartalom kötelező!')),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      final noteRef = FirebaseFirestore.instance.collection('notes').doc();
      final noteId = noteRef.id;

      // Címkék mentése a 'tags' kollekcióba
      for (final tag in _tags) {
        FirebaseFirestore.instance
            .collection('tags')
            .doc(tag)
            .set({'name': tag});
      }

      String? mp3Url;
      if (isFileValid(_selectedMp3File)) {
        final mp3Ref = FirebaseStorage.instance
            .ref('notes/$noteId/${_selectedMp3File!['name']}');
        await mp3Ref.putData(
            Uint8List.fromList(_selectedMp3File!['bytes'] as List<int>));
        mp3Url = await mp3Ref.getDownloadURL();
      }

      String? videoUrl;
      if (isFileValid(_selectedVideoFile)) {
        final videoRef = FirebaseStorage.instance
            .ref('notes/$noteId/${_selectedVideoFile!['name']}');
        await videoRef.putData(
            Uint8List.fromList(_selectedVideoFile!['bytes'] as List<int>));
        videoUrl = await videoRef.getDownloadURL();
      }

      // Firestore mentés
      final noteData = {
        'title': _titleController.text,
        'category': _selectedCategory,
        'status': 'Draft',
        'modified': Timestamp.now(),
        'pages': [htmlContent],
        'type': 'interactive', // Típus beállítása
        'tags': _tags,
      };
      if (mp3Url != null) noteData['audioUrl'] = mp3Url;
      if (videoUrl != null) noteData['videoUrl'] = videoUrl;

      await noteRef.set(noteData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Interaktív jegyzet sikeresen létrehozva!')),
        );

        setState(() {
          _titleController.clear();
          _htmlContentController.clear();
          _selectedCategory = null;
          _selectedMp3File = null;
          _selectedVideoFile = null;
          _videoController?.dispose();
          _videoController = null;
          _tags.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba történt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 250, 251),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'interactive_notes'),
          Expanded(
            child: Column(
              children: [
                Header(onSearchChanged: (_) {}),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Új Interaktív Jegyzet Létrehozása',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
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
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedCategory = value),
                              decoration: const InputDecoration(
                                labelText: 'Kategória',
                                border: OutlineInputBorder(),
                              ),
                            ),
                             const SizedBox(height: 16),
                            // Címke kezelő
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Címkék (max 4)',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  children: _tags
                                      .map((tag) => Chip(
                                            label: Text(tag),
                                            onDeleted: () {
                                              setState(() {
                                                _tags.remove(tag);
                                              });
                                            },
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _tagController,
                                        enabled: _tags.length < 4,
                                        decoration: const InputDecoration(
                                            hintText: 'Új címke',
                                            isDense: true),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _tags.length >= 4
                                          ? null
                                          : () {
                                              final newTag = _tagController.text.trim();
                                              final isDuplicate = _tags.any((t) => t.toLowerCase() == newTag.toLowerCase());
                                              if (newTag.isNotEmpty && !isDuplicate) {
                                                setState(() {
                                                  _tags.add(newTag);
                                                });
                                                _tagController.clear();
                                              }
                                            },
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text('HTML Tartalom',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                             TextField(
                              controller: _htmlContentController,
                              decoration: const InputDecoration(
                                labelText: 'Interaktív HTML kód helye',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 15,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.visibility),
                              label: const Text('Előnézet megjelenítése/frissítése'),
                              onPressed: () {
                                try {
                                  final htmlContent = _htmlContentController.text;
                                  if (htmlContent.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Az előnézethez adj meg HTML tartalmat!'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // HTML validáció
                                  final document = parse(htmlContent);

                                  if (document.documentElement == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Érvénytelen HTML tartalom!'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    setState(() {
                                      _showPreview = false;
                                      _previewWebViewController = null;
                                    });
                                  } else {
                                    // A korábbi blob URL-t felszabadítjuk a memóriaszivárgás elkerülése érdekében
                                    if (_blobUrl != null) {
                                      html.Url.revokeObjectUrl(_blobUrl!);
                                    }

                                    final blob = html.Blob([htmlContent], 'text/html');
                                    _blobUrl = html.Url.createObjectUrlFromBlob(blob);

                                    setState(() {
                                      _previewWebViewController =
                                          WebViewController()
                                            ..loadRequest(Uri.parse(_blobUrl!));
                                      _showPreview = true;
                                    });
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Váratlan hiba történt: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                            if (_showPreview && _previewWebViewController != null) ...[
                              const SizedBox(height: 16),
                              const Text('Előnézet:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                height: 600,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: WebViewWidget(controller: _previewWebViewController!),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.audiotrack),
                                  label: const Text('MP3 feltöltése'),
                                  onPressed: _pickMp3File,
                                ),
                                const SizedBox(width: 16),
                                if (_selectedMp3File != null)
                                  Text(
                                      'Fájl: ${_selectedMp3File!['name']} (${(_selectedMp3File!['size'] / 1024).toStringAsFixed(2)} KB)'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.video_library),
                                  label: const Text('Videó feltöltése'),
                                  onPressed: _pickVideoFile,
                                ),
                                const SizedBox(width: 16),
                                if (_selectedVideoFile != null)
                                  Text(
                                      'Fájl: ${_selectedVideoFile!['name']} (${(_selectedVideoFile!['size'] / 1024).toStringAsFixed(2)} KB)'),
                              ],
                            ),
                            if (!kIsWeb &&
                                _videoController != null &&
                                _videoController!.value.isInitialized)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: AspectRatio(
                                  aspectRatio:
                                      _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _isUploading ? null : _uploadNote,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 32),
                              ),
                              child: _isUploading
                                  ? const CircularProgressIndicator(
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    )
                                  : const Text('Interaktív Jegyzet Létrehozása'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 
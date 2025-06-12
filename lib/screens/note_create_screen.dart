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
import 'dart:html' as html;

import '../widgets/sidebar.dart';
import '../widgets/header.dart';

class NoteCreateScreen extends StatefulWidget {
  const NoteCreateScreen({super.key});

  @override
  State<NoteCreateScreen> createState() => _NoteCreateScreenState();
}

class _NoteCreateScreenState extends State<NoteCreateScreen> {
  final _titleController = TextEditingController();
  final _htmlSourceController = TextEditingController();
  String? _selectedCategory;
  Map<String, dynamic>? _selectedMp3File;
  Map<String, dynamic>? _selectedVideoFile;
  bool _isUploading = false;
  List<String> _categories = [];
  VideoPlayerController? _videoController;
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
    _htmlSourceController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('categories').get();
    setState(() {
      _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
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
        if (bytes.length > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('A hangfájl mérete nem haladhatja meg az 5 MB-ot!')),
          );
          return;
        }
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
    final htmlContent = _htmlSourceController.text;

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
      };
      if (mp3Url != null) noteData['audioUrl'] = mp3Url;
      if (videoUrl != null) noteData['videoUrl'] = videoUrl;

      await noteRef.set(noteData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jegyzet sikeresen létrehozva!')),
        );

        setState(() {
          _titleController.clear();
          _htmlSourceController.clear();
          _selectedCategory = null;
          _selectedMp3File = null;
          _selectedVideoFile = null;
          _videoController?.dispose();
          _videoController = null;
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
          const Sidebar(selectedMenu: 'categories'),
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
                            const Text('Új Jegyzet Létrehozása',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _titleController,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
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
                            const SizedBox(height: 24),
                            const Text('Jegyzet tartalma (HTML)',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _htmlSourceController,
                              decoration: const InputDecoration(
                                labelText: 'HTML forráskód',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              style: const TextStyle(fontSize: 9.0),
                              maxLines: 15,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.visibility),
                              label: const Text('Előnézet'),
                              onPressed: () {
                                final htmlContent = _htmlSourceController.text;
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    )
                                  : const Text('Jegyzet Létrehozása'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

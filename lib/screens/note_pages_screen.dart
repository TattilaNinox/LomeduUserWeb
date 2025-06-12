import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NotePagesScreen extends StatefulWidget {
  final String noteId;

  const NotePagesScreen({super.key, required this.noteId});

  @override
  State<NotePagesScreen> createState() => _NotePagesScreenState();
}

class _NotePagesScreenState extends State<NotePagesScreen> {
  DocumentSnapshot? _noteSnapshot;
  int _currentPageIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('notes')
        .doc(widget.noteId)
        .get();

    if (mounted) {
      setState(() => _noteSnapshot = snapshot);
      _setupMedia(snapshot.data());
    }
  }

  void _setupMedia(Map<String, dynamic>? data) {
    if (data == null) return;
    
    final audioUrl = data['audioUrl'] as String?;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      _audioPlayer.setUrl(audioUrl);
    }

    final pages = data['pages'] as List<dynamic>? ?? [];
    if (pages.isNotEmpty) {
      final currentPage = pages[_currentPageIndex] as String;
      if (currentPage.contains('<script')) {
        _webViewController = WebViewController()
          ..loadHtmlString(currentPage);
      }
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
        _updatePageContent();
      });
    }
  }

  void _goToNextPage(List<dynamic> pages) {
    if (_currentPageIndex < pages.length - 1) {
      setState(() {
        _currentPageIndex++;
        _updatePageContent();
      });
    }
  }

  void _updatePageContent() {
    final data = _noteSnapshot!.data() as Map<String, dynamic>;
    final pages = data['pages'] as List<dynamic>? ?? [];
    final currentPage = pages.isNotEmpty
        ? pages[_currentPageIndex] as String
        : '';
        
    if (currentPage.contains('<script')) {
      _webViewController = WebViewController()
        ..loadHtmlString(currentPage);
    } else {
      _webViewController = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_noteSnapshot == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _noteSnapshot!.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Cím nélkül';
    final pages = data['pages'] as List<dynamic>? ?? [];
    final currentPage = pages.isNotEmpty
        ? pages[_currentPageIndex] as String
        : 'Ez a jegyzet nem tartalmaz tartalmat.';

    final bool isWebView = _webViewController != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/notes'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (pages.isNotEmpty)
              Text(
                'Oldal ${_currentPageIndex + 1} / ${pages.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: isWebView
                  ? WebViewWidget(controller: _webViewController!)
                  : SingleChildScrollView(
                      child: Html(
                        data: currentPage,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _currentPageIndex > 0 ? _goToPreviousPage : null,
                  child: const Text('Előző oldal'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _currentPageIndex < pages.length - 1
                      ? () => _goToNextPage(pages)
                      : null,
                  child: const Text('Következő oldal'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty)
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _audioPlayer.play,
                    child: const Icon(Icons.play_arrow),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _audioPlayer.pause,
                    child: const Icon(Icons.pause),
                  ),
                ],
              )
            else
              const Text('Nincs hanganyag elérhető.'),
          ],
        ),
      ),
    );
  }
}

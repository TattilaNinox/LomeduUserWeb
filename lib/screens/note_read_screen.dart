import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/audio_preview_player.dart';

/// Felhasználói (csak olvasás) nézet szöveges jegyzetekhez.
///
/// - Csak megjelenítés és hanganyag lejátszás
/// - Nincsenek admin műveletek
class NoteReadScreen extends StatefulWidget {
  final String noteId;

  const NoteReadScreen({super.key, required this.noteId});

  @override
  State<NoteReadScreen> createState() => _NoteReadScreenState();
}

class _NoteReadScreenState extends State<NoteReadScreen> {
  DocumentSnapshot? _noteSnapshot;
  int _currentPageIndex = 0;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('notes')
        .doc(widget.noteId)
        .get();

    if (!mounted) return;
    setState(() => _noteSnapshot = snapshot);
    _setupMedia(snapshot.data());
  }

  void _setupMedia(Map<String, dynamic>? data) {
    if (data == null) return;
    final pages = data['pages'] as List<dynamic>? ?? [];
    if (pages.isNotEmpty) {
      final currentPage = pages[_currentPageIndex] as String;
      if (currentPage.contains('<script')) {
        _webViewController = WebViewController()..loadHtmlString(currentPage);
      }
    }
  }

  void _updatePageContent() {
    final data = _noteSnapshot!.data() as Map<String, dynamic>;
    final pages = data['pages'] as List<dynamic>? ?? [];
    final currentPage =
        pages.isNotEmpty ? pages[_currentPageIndex] as String : '';
    if (currentPage.contains('<script')) {
      _webViewController = WebViewController()..loadHtmlString(currentPage);
    } else {
      _webViewController = null;
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (pages.isNotEmpty)
              Text(
                'Oldal ${_currentPageIndex + 1} / ${pages.length}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            if (data['audioUrl'] != null &&
                data['audioUrl'].toString().isNotEmpty)
              AudioPreviewPlayer(audioUrl: data['audioUrl'])
            else
              const Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text('Nincs hanganyag elérhető.'),
              ),
          ],
        ),
      ),
    );
  }
}

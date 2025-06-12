import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:html/parser.dart' show parse;
import 'dart:html' as html;

class InteractiveNoteViewScreen extends StatefulWidget {
  final String noteId;

  const InteractiveNoteViewScreen({super.key, required this.noteId});

  @override
  State<InteractiveNoteViewScreen> createState() =>
      _InteractiveNoteViewScreenState();
}

class _InteractiveNoteViewScreenState extends State<InteractiveNoteViewScreen> {
  DocumentSnapshot? _noteSnapshot;
  WebViewController? _webViewController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void dispose() {
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('notes')
        .doc(widget.noteId)
        .get();

    if (!mounted) return;

    WebViewController? newWebViewController;
    final data = snapshot.data();
    if (data != null) {
      final pages = data['pages'] as List<dynamic>? ?? [];
      if (pages.isNotEmpty) {
        final htmlContent = pages.first as String;
        if (htmlContent.isNotEmpty) {
          // HTML validáció
          final document = parse(htmlContent);
          if (document.documentElement == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Érvénytelen HTML tartalom!'),
                    backgroundColor: Colors.red),
              );
            }
          } else {
            // A HTML érvényes, létrehozzuk a WebView-t
            final blob = html.Blob([htmlContent], 'text/html');
            _blobUrl = html.Url.createObjectUrlFromBlob(blob);

            newWebViewController = WebViewController()
              ..loadRequest(Uri.parse(_blobUrl!));
          }
        }
      }
      final audioUrl = data['audioUrl'] as String?;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        _audioPlayer.setUrl(audioUrl);
      }
    }

    if (mounted) {
      setState(() {
        _noteSnapshot = snapshot;
        _webViewController = newWebViewController;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_noteSnapshot == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Betöltés...'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/notes'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _noteSnapshot!.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Cím nélkül';
    
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_webViewController != null)
              Expanded(
                child: WebViewWidget(controller: _webViewController!),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Nem sikerült betölteni az interaktív tartalmat. Ellenőrizd a HTML kódot vagy a hálózati kapcsolatot!',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
            ]
          ],
        ),
      ),
    );
  }
} 
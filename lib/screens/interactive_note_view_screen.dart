import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' show parse;
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'dart:async';

import '../widgets/audio_preview_player.dart';

class InteractiveNoteViewScreen extends StatefulWidget {
  final String noteId;

  const InteractiveNoteViewScreen({super.key, required this.noteId});

  @override
  State<InteractiveNoteViewScreen> createState() =>
      _InteractiveNoteViewScreenState();
}

class _InteractiveNoteViewScreenState extends State<InteractiveNoteViewScreen> {
  DocumentSnapshot? _noteSnapshot;
  late final String _viewId;
  final web.HTMLIFrameElement _iframeElement = web.HTMLIFrameElement();
  bool _hasContent = false;

  late final StreamSubscription<DocumentSnapshot> _subscription;

  @override
  void initState() {
    super.initState();

    _viewId = "interactive-note-iframe-${widget.noteId}";

    _iframeElement
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry
        .registerViewFactory(_viewId, (int viewId) => _iframeElement);

    _subscription = FirebaseFirestore.instance
        .collection('notes')
        .doc(widget.noteId)
        .snapshots()
        .listen(_handleSnapshot);
  }

  void _handleSnapshot(DocumentSnapshot snapshot) {
    if (!mounted) return;

    String? htmlContentToLoad;
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data != null) {
      final pages = data['pages'] as List<dynamic>? ?? [];
      if (pages.isNotEmpty) {
        final htmlContent = pages.first as String? ?? '';
        if (htmlContent.isNotEmpty) {
          htmlContentToLoad = htmlContent;
        }
      }
    }

    setState(() {
      _noteSnapshot = snapshot;
      if (htmlContentToLoad != null) {
        _iframeElement.src =
            'data:text/html;charset=utf-8,${Uri.encodeComponent(htmlContentToLoad)}';
        _hasContent = true;
      } else {
        _hasContent = false;
      }
    });
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
            if (_hasContent)
              Expanded(
                child: HtmlElementView(viewType: _viewId),
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
            if (data['audioUrl'] != null &&
                data['audioUrl'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              AudioPreviewPlayer(audioUrl: data['audioUrl']),
            ]
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
} 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'dart:async';
// no extra JS interop needed
import '../widgets/audio_preview_player.dart';
import 'quiz_page.dart';

class InteractiveNoteViewScreen extends StatefulWidget {
  final String noteId;
  final String? from;

  const InteractiveNoteViewScreen({
    super.key,
    required this.noteId,
    this.from,
  });

  @override
  State<InteractiveNoteViewScreen> createState() =>
      _InteractiveNoteViewScreenState();
}

class _InteractiveNoteViewScreenState extends State<InteractiveNoteViewScreen> {
  DocumentSnapshot? _noteSnapshot;
  late final String _viewId;
  final web.HTMLIFrameElement _iframeElement = web.HTMLIFrameElement();
  bool _hasContent = false;
  // Using srcdoc, no object URL needed

  late final StreamSubscription<DocumentSnapshot> _subscription;
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();

    _viewId = "interactive-note-iframe-${widget.noteId}";

    _iframeElement
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none';

    // More permissive sandbox settings
    _iframeElement.sandbox.add('allow-scripts');
    _iframeElement.sandbox.add('allow-same-origin');
    _iframeElement.sandbox.add('allow-forms');
    _iframeElement.sandbox.add('allow-popups');

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry
        .registerViewFactory(_viewId, (int viewId) => _iframeElement);

    _subscription = FirebaseFirestore.instance
        .collection('notes')
        .doc(widget.noteId)
        .snapshots()
        .listen(
          _handleSnapshot,
          onError: (error) {
            // Firestore permission denied hiba (zárt jegyzet)
            if (mounted) {
              setState(() => _accessDenied = true);
              _showAccessDeniedAndGoBack();
            }
          },
        );
  }

  void _showAccessDeniedAndGoBack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Ez a tartalom csak előfizetőknek érhető el. Vásárolj előfizetést a teljes hozzáféréshez!'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Előfizetés',
          onPressed: () {
            context.go('/account');
          },
        ),
      ),
    );
    // Visszairányítás a jegyzetek listához
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (widget.from != null && widget.from!.isNotEmpty) {
          context.go(widget.from!);
        } else {
          context.go('/notes');
        }
      }
    });
  }

  void _handleSnapshot(DocumentSnapshot snapshot) {
    if (!mounted) return;

    // Ha a hozzáférés meg lett tagadva, ne dolgozzuk fel
    if (_accessDenied) return;

    // Ellenőrizzük, hogy létezik-e a dokumentum
    if (!snapshot.exists) {
      setState(() => _accessDenied = true);
      _showAccessDeniedAndGoBack();
      return;
    }

    // No object URL to revoke when using srcdoc

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
      if (htmlContentToLoad != null && htmlContentToLoad.isNotEmpty) {
        // Use srcdoc for reliable inline HTML rendering
        _iframeElement.srcdoc = htmlContentToLoad;
        _hasContent = true;
      } else {
        _hasContent = false;
      }
    });
  }

  void _handleQuizNavigation() {
    final data = _noteSnapshot!.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? '';
    final questionBankId = data['questionBankId'] as String?;
    
    if (questionBankId != null && (type == 'dynamic_quiz' || type == 'dynamic_quiz_dual')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuizPage(
            noteId: widget.noteId,
            questionBankId: questionBankId,
            quizType: type,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_noteSnapshot == null) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Betöltés...',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).primaryColor,
              size: isMobile ? 20 : 22,
            ),
            onPressed: () {
              if (widget.from != null && widget.from!.isNotEmpty) {
                context.go(widget.from!);
              } else {
                context.go('/notes');
              }
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _noteSnapshot!.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Cím nélkül';
    final type = data['type'] as String? ?? '';
    final questionBankId = data['questionBankId'] as String?;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).primaryColor,
            size: isMobile ? 20 : 22,
          ),
          onPressed: () {
            if (widget.from != null && widget.from!.isNotEmpty) {
              context.go(widget.from!);
            } else {
              context.go('/notes');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.home,
              color: Theme.of(context).primaryColor,
              size: isMobile ? 20 : 22,
            ),
            onPressed: () => context.go('/notes'),
            tooltip: 'Vissza a jegyzetek listájához',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quiz type handling
            if (type == 'dynamic_quiz' || type == 'dynamic_quiz_dual') ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        type == 'dynamic_quiz_dual' 
                            ? Icons.quiz_outlined 
                            : Icons.quiz,
                        size: 80,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        type == 'dynamic_quiz_dual' 
                            ? 'Dinamikus kétválaszos kvíz'
                            : 'Dinamikus kvíz',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: questionBankId != null ? _handleQuizNavigation : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Kvíz Indítása'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                      if (questionBankId == null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Hiba: Nincs kérdésbank azonosító',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else if (_hasContent) ...[
              // Regular interactive content
              Expanded(
                child: HtmlElementView(viewType: _viewId),
              )
            ] else ...[
              // No content fallback
              const Expanded(
                child: Center(
                  child: Text(
                    'Nem sikerült betölteni az interaktív tartalmat. Ellenőrizd a HTML kódot vagy a hálózati kapcsolatot!',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
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
    // Cancel Firestore subscription
    _subscription.cancel();
    super.dispose();
  }
}

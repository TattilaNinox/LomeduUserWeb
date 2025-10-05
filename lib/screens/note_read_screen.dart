import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import '../widgets/audio_preview_player.dart';
import '../utils/filter_storage.dart';

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
            // URL paraméterekkel vissza navigálás a szűrők megőrzéséhez
            final uri = Uri(
              path: '/notes',
              queryParameters: {
                if (FilterStorage.searchText != null &&
                    FilterStorage.searchText!.isNotEmpty)
                  'q': FilterStorage.searchText!,
                if (FilterStorage.status != null)
                  'status': FilterStorage.status!,
                if (FilterStorage.category != null)
                  'category': FilterStorage.category!,
                if (FilterStorage.science != null)
                  'science': FilterStorage.science!,
                if (FilterStorage.tag != null) 'tag': FilterStorage.tag!,
                if (FilterStorage.type != null) 'type': FilterStorage.type!,
              },
            );
            context.go(uri.toString());
          },
        ),
      ),
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: isWebView
                        ? WebViewWidget(controller: _webViewController!)
                        : SingleChildScrollView(
                            child: Html(
                              data: currentPage,
                              style: {
                                "body": Style(
                                  fontSize: FontSize(isMobile ? 16 : 18),
                                  lineHeight: const LineHeight(1.6),
                                  color: const Color(0xFF2D3748),
                                  fontFamily: 'Inter',
                                ),
                                "h1": Style(
                                  fontSize: FontSize(isMobile ? 20 : 24),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A202C),
                                  margin: Margins.only(bottom: 16),
                                ),
                                "h2": Style(
                                  fontSize: FontSize(isMobile ? 18 : 22),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2D3748),
                                  margin: Margins.only(bottom: 12),
                                ),
                                "h3": Style(
                                  fontSize: FontSize(isMobile ? 16 : 20),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4A5568),
                                  margin: Margins.only(bottom: 10),
                                ),
                                "p": Style(
                                  fontSize: FontSize(isMobile ? 15 : 17),
                                  lineHeight: const LineHeight(1.6),
                                  color: const Color(0xFF2D3748),
                                  margin: Margins.only(bottom: 12),
                                ),
                                "ul": Style(
                                  margin: Margins.only(bottom: 12),
                                ),
                                "ol": Style(
                                  margin: Margins.only(bottom: 12),
                                ),
                                "li": Style(
                                  fontSize: FontSize(isMobile ? 15 : 17),
                                  lineHeight: const LineHeight(1.5),
                                  color: const Color(0xFF2D3748),
                                  margin: Margins.only(bottom: 6),
                                ),
                                "blockquote": Style(
                                  fontSize: FontSize(isMobile ? 15 : 17),
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFF4A5568),
                                  backgroundColor: const Color(0xFFF7FAFC),
                                  border: Border(
                                    left: BorderSide(
                                      color: const Color(0xFFE2E8F0),
                                      width: 4,
                                    ),
                                  ),
                                  padding: HtmlPaddings.only(
                                      left: 16, top: 12, bottom: 12, right: 16),
                                  margin: Margins.only(bottom: 16),
                                ),
                                "code": Style(
                                  backgroundColor: const Color(0xFFF7FAFC),
                                  color: const Color(0xFFE53E3E),
                                  fontFamily: 'monospace',
                                  fontSize: FontSize(isMobile ? 13 : 15),
                                  padding: HtmlPaddings.symmetric(
                                      horizontal: 4, vertical: 2),
                                ),
                                "pre": Style(
                                  backgroundColor: const Color(0xFFF7FAFC),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  padding: HtmlPaddings.all(12),
                                  margin: Margins.only(bottom: 16),
                                ),
                              },
                            ),
                          ),
                  ),
                ),
              ),
            ),
            if (data['audioUrl'] != null &&
                data['audioUrl'].toString().isNotEmpty)
              Container(
                margin: EdgeInsets.fromLTRB(
                  isMobile ? 12 : 16,
                  0,
                  isMobile ? 12 : 16,
                  isMobile ? 12 : 16,
                ),
                child: AudioPreviewPlayer(audioUrl: data['audioUrl']),
              ),
          ],
        ),
      ),
    );
  }
}

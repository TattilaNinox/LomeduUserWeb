import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/firebase_config.dart';
import 'quiz_viewer.dart';
import 'quiz_viewer_dual.dart';
import 'mini_audio_player.dart';

class NoteListTile extends StatelessWidget {
  final String id;
  final String title;
  final String type; // standard, interactive, deck, dynamic_quiz...
  final bool hasDoc;
  final bool hasAudio;
  final bool hasVideo;
  final int? deckCount;
  final String? questionBankId;
  final String? audioUrl;

  const NoteListTile({
    super.key,
    required this.id,
    required this.title,
    required this.type,
    required this.hasDoc,
    required this.hasAudio,
    required this.hasVideo,
    this.deckCount,
    this.questionBankId,
    this.audioUrl,
  });

  IconData _typeIcon() {
    switch (type) {
      case 'deck':
        return Icons.style;
      case 'interactive':
        return Icons.touch_app;
      case 'dynamic_quiz':
        return Icons.quiz;
      case 'dynamic_quiz_dual':
        return Icons.quiz_outlined;
      default:
        return Icons.menu_book;
    }
  }

  void _open(BuildContext context) {
    if (type == 'interactive') {
      context.go('/interactive-note/$id');
    } else if (type == 'dynamic_quiz' || type == 'dynamic_quiz_dual') {
      _openQuiz(context, dualMode: type == 'dynamic_quiz_dual');
    } else if (type == 'deck') {
      context.go('/deck/$id/view');
    } else {
      context.go('/note/$id');
    }
  }

  Future<void> _openQuiz(BuildContext context, {required bool dualMode}) async {
    try {
      String? bankId = questionBankId;
      if (bankId == null || bankId.isEmpty) {
        final noteDoc =
            await FirebaseConfig.firestore.collection('notes').doc(id).get();
        bankId = (noteDoc.data() ?? const {})['questionBankId'] as String?;
      }
      if (bankId == null || bankId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Hiba: a kvízhez nincs kérdésbank társítva.')),
          );
        }
        return;
      }

      final bankDoc = await FirebaseConfig.firestore
          .collection('question_banks')
          .doc(bankId)
          .get();
      if (!bankDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hiba: a kérdésbank nem található.')),
          );
        }
        return;
      }
      final bank = bankDoc.data()!;
      final questions =
          List<Map<String, dynamic>>.from(bank['questions'] ?? []);
      if (questions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ez a kérdésbank nem tartalmaz kérdéseket.')),
          );
        }
        return;
      }

      questions.shuffle();
      final selected = questions.take(10).toList();

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: const EdgeInsets.all(8),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: dualMode
                ? QuizViewerDual(questions: selected)
                : QuizViewer(questions: selected),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bezárás'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kvíz megnyitási hiba: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        const Color(0xFFF5F7F6); // elegáns zöldesbarna árnyalatú szürke
    final Color borderColor =
        const Color(0xFFE8EDE9); // finomabb zöldesbarna keret szín
    final Color shadowColor = Colors.black.withOpacity(0.05); // finom árnyék

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(16),
            splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
            highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 520;

                  Widget audioWidget = const SizedBox.shrink();
                  if (hasAudio && (audioUrl?.isNotEmpty ?? false)) {
                    audioWidget = SizedBox(
                      width: isNarrow ? double.infinity : 180,
                      child: MiniAudioPlayer(audioUrl: audioUrl!),
                    );
                  } else if (hasAudio) {
                    audioWidget = const Tooltip(
                      message: 'Hangjegyzet elérhető',
                      child:
                          Icon(Icons.audiotrack, size: 16, color: Colors.green),
                    );
                  }

                  final Widget titleAndMeta = Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF2D3748),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _typeIcon(),
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            titleAndMeta,
                          ],
                        ),
                        if (hasAudio) ...[
                          const SizedBox(height: 12),
                          audioWidget,
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _typeIcon(),
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      titleAndMeta,
                      if (hasAudio) ...[
                        const SizedBox(width: 16),
                        audioWidget,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

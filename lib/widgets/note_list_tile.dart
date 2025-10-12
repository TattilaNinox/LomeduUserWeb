import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/firebase_config.dart';
import '../utils/filter_storage.dart';
import 'quiz_viewer.dart';
import 'quiz_viewer_dual.dart';
import '../models/quiz_models.dart';
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
      case 'source':
        return Icons.source;
      default:
        return Icons.menu_book;
    }
  }

  void _open(BuildContext context) {
    // Menteni a szűrők állapotát navigáció előtt
    FilterStorage.saveFilters(
      searchText: FilterStorage.searchText ?? '',
      status: FilterStorage.status,
      category: FilterStorage.category,
      science: FilterStorage.science,
      tag: FilterStorage.tag,
      type: FilterStorage.type,
    );

    final isMobile = MediaQuery.of(context).size.width < 600;

    if (type == 'interactive') {
      context.go('/interactive-note/$id');
    } else if (type == 'dynamic_quiz' || type == 'dynamic_quiz_dual') {
      if (isMobile) {
        context.go('/quiz/$id');
      } else {
        _openQuiz(context, dualMode: type == 'dynamic_quiz_dual');
      }
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
      final selected =
          questions.take(10).map((q) => Question.fromMap(q)).toList();

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: const EdgeInsets.all(8),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: dualMode
                ? QuizViewerDual(
                    questions: selected,
                    onQuizComplete: (result) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Kvíz eredménye: ${result.score}/${result.totalQuestions}'),
                        ),
                      );
                    },
                  )
                : QuizViewer(
                    questions: selected.map((q) => q.toMap()).toList()),
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
    const Color cardColor =
        Color(0xFFF5F7F6); // elegáns zöldesbarna árnyalatú szürke
    const Color borderColor = Color(0xFFE8EDE9); // finom keret (visszaállítva)
    final Color shadowColor =
        Colors.black.withValues(alpha: 0.03); // még finomabb árnyék mobilon is

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
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(16),
            splashColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            highlightColor:
                Theme.of(context).primaryColor.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 520;

                  Widget audioWidget = const SizedBox.shrink();
                  if (hasAudio && (audioUrl?.isNotEmpty ?? false)) {
                    audioWidget = Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: isNarrow ? double.infinity : 150,
                        child:
                            MiniAudioPlayer(audioUrl: audioUrl!, compact: true),
                      ),
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
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                // ikon körül NINCS karmazsin keret a jegyzet-listában
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
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          // ikon körül NINCS karmazsin keret a jegyzet-listában
                        ),
                        child: Icon(
                          _typeIcon(),
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Bal oldali cím/meta
                      titleAndMeta,
                      // Középre igazított lejátszó a sor közepén
                      if (hasAudio)
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 150,
                              child: MiniAudioPlayer(
                                audioUrl: audioUrl!,
                                compact: true,
                              ),
                            ),
                          ),
                        ),
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

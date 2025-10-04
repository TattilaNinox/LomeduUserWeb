import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NoteListTile extends StatelessWidget {
  final String id;
  final String title;
  final String type; // standard, interactive, deck, dynamic_quiz...
  final bool hasDoc;
  final bool hasAudio;
  final bool hasVideo;
  final int? deckCount;

  const NoteListTile({
    super.key,
    required this.id,
    required this.title,
    required this.type,
    required this.hasDoc,
    required this.hasAudio,
    required this.hasVideo,
    this.deckCount,
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
    if (type == 'interactive' ||
        type == 'dynamic_quiz' ||
        type == 'dynamic_quiz_dual') {
      context.go('/interactive-note/$id');
    } else if (type == 'deck') {
      context.go('/deck/$id/view');
    } else {
      context.go('/note/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_typeIcon(), color: Theme.of(context).primaryColor),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: type == 'deck' && deckCount != null
          ? Text('$deckCount kártya')
          : null,
      onTap: () => _open(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ignore_for_file: avoid_print, unused_import
// One-off script: add 'science': 'Alap' to notes missing the field
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:orlomed_admin_web/core/firebase_config.dart';

Future<void> main() async {
  print('Initializing Firebase...');
  await FirebaseConfig.initialize();

  final fb = FirebaseFirestore.instance;
  const defaultScience = 'Alap';

  final snap =
      await fb.collection('notes').where('science', isNull: true).get();
  print('Documents to update: ${snap.docs.length}');

  for (final doc in snap.docs) {
    await doc.reference.update({'science': defaultScience});
  }

  print('Done: all missing notes updated.');
}

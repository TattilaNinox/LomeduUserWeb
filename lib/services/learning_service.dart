import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flashcard_learning_data.dart';

class LearningService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache a deck esedékes kártyáinak indexeire
  static final Map<String, List<int>> _dueCardsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidity = Duration(minutes: 5);

  /// Egy kártya tanulási adatainak frissítése értékelés alapján
  static Future<void> updateUserLearningData(
    String cardId, // deckId#index formátum
    String rating, // "Again" | "Hard" | "Good" | "Easy"
    String categoryId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Jelenlegi adatok lekérése
      final currentData = await _getCurrentLearningData(cardId, categoryId);
      
      // Új állapot kalkulálása
      final newData = _calculateNextState(currentData, rating);
      
      // Mentés az új útvonalra
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .collection('learning')
          .doc(cardId)
          .set(newData.toMap());

      // Legacy dokumentum törlése, ha létezik
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('user_learning_data')
          .doc(cardId)
          .delete();

      // Deck és kategória statisztikák frissítése
      await _updateDeckSnapshot(cardId.split('#')[0], cardId.split('#')[1], rating, currentData.lastRating);
      await _updateCategoryStats(categoryId, rating, currentData.lastRating);

      // Cache invalidálása
      _invalidateDeckCache(cardId.split('#')[0]);

    } catch (e) {
      print('Error updating learning data: $e');
      rethrow;
    }
  }

  /// Esedékes kártyák indexeinek lekérése egy deck-hez
  static Future<List<int>> getDueFlashcardIndicesForDeck(String deckId) async {
    // Cache ellenőrzése
    if (_dueCardsCache.containsKey(deckId) && 
        _cacheTimestamps.containsKey(deckId) &&
        DateTime.now().difference(_cacheTimestamps[deckId]!) < _cacheValidity) {
      return _dueCardsCache[deckId]!;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Deck adatok lekérése
      final deckDoc = await _firestore.collection('notes').doc(deckId).get();
      if (!deckDoc.exists) return [];

      final deckData = deckDoc.data() as Map<String, dynamic>;
      final flashcards = List<Map<String, dynamic>>.from(deckData['flashcards'] ?? []);
      final categoryId = deckData['category'] as String? ?? 'default';

      final dueIndices = <int>[];
      final now = Timestamp.now();

      // LEARNING és REVIEW állapotú esedékes kártyák
      for (int i = 0; i < flashcards.length; i++) {
        final cardId = '${deckId}#$i';
        final learningData = await _getCurrentLearningData(cardId, categoryId);
        
        if (learningData.state != 'NEW' && learningData.nextReview.seconds <= now.seconds) {
          dueIndices.add(i);
        }
      }

      // NEW kártyák (legfeljebb newCardLimit)
      int newCardCount = 0;
      for (int i = 0; i < flashcards.length && newCardCount < SpacedRepetitionConfig.newCardLimit; i++) {
        final cardId = '${deckId}#$i';
        final learningData = await _getCurrentLearningData(cardId, categoryId);
        
        if (learningData.state == 'NEW') {
          dueIndices.add(i);
          newCardCount++;
        }
      }

      // Cache mentése
      _dueCardsCache[deckId] = dueIndices;
      _cacheTimestamps[deckId] = DateTime.now();

      return dueIndices;

    } catch (e) {
      print('Error getting due cards: $e');
      return [];
    }
  }

  /// Pakli tanulási előzményeinek törlése
  static Future<void> resetDeckProgress(String deckId, int cardCount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Deck kategóriájának lekérése
      final deckDoc = await _firestore.collection('notes').doc(deckId).get();
      if (!deckDoc.exists) return;

      final deckData = deckDoc.data() as Map<String, dynamic>;
      final categoryId = deckData['category'] as String? ?? 'default';

      // Kártya dokumentumok törlése
      for (int i = 0; i < cardCount; i++) {
        final cardId = '${deckId}#$i';
        
        // Új útvonal törlése
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('categories')
            .doc(categoryId)
            .collection('learning')
            .doc(cardId)
            .delete();

        // Legacy útvonal törlése
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('user_learning_data')
            .doc(cardId)
            .delete();
      }

      // Kategória statisztikák törlése
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('category_stats')
          .doc(categoryId)
          .delete();

      // Deck snapshot törlése
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('deck_stats')
          .doc(deckId)
          .delete();

      // Cache invalidálása
      _invalidateDeckCache(deckId);

    } catch (e) {
      print('Error resetting deck progress: $e');
      rethrow;
    }
  }

  /// Jelenlegi tanulási adatok lekérése
  static Future<FlashcardLearningData> _getCurrentLearningData(String cardId, String categoryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return _getDefaultLearningData();
      }

      // Új útvonal ellenőrzése
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .collection('learning')
          .doc(cardId)
          .get();

      if (doc.exists) {
        return FlashcardLearningData.fromMap(doc.data()!);
      }

      // Legacy útvonal ellenőrzése
      final legacyDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('user_learning_data')
          .doc(cardId)
          .get();

      if (legacyDoc.exists) {
        return FlashcardLearningData.fromMap(legacyDoc.data()!);
      }

      return _getDefaultLearningData();

    } catch (e) {
      print('Error getting current learning data: $e');
      return _getDefaultLearningData();
    }
  }

  /// Alapértelmezett tanulási adatok
  static FlashcardLearningData _getDefaultLearningData() {
    final now = Timestamp.now();
    return FlashcardLearningData(
      state: 'NEW',
      interval: 0,
      easeFactor: 2.5,
      repetitions: 0,
      lastReview: now,
      nextReview: now,
      lastRating: 'Again',
    );
  }

  /// SM-2 algoritmus alapú következő állapot kalkulálása
  static FlashcardLearningData _calculateNextState(
    FlashcardLearningData current,
    String rating,
  ) {
    final now = Timestamp.now();
    double newEaseFactor = current.easeFactor;
    int newInterval = current.interval;
    int newRepetitions = current.repetitions;
    String newState = current.state;

    switch (rating) {
      case 'Again':
        newEaseFactor = (current.easeFactor - 0.2).clamp(
          SpacedRepetitionConfig.minEaseFactor,
          SpacedRepetitionConfig.maxEaseFactor,
        );
        newRepetitions = 0;
        
        if (current.state == 'REVIEW') {
          newState = 'LEARNING';
          newInterval = SpacedRepetitionConfig.lapseSteps.first;
        } else {
          newState = 'LEARNING';
          newInterval = SpacedRepetitionConfig.learningSteps.first;
        }
        break;

      case 'Hard':
        newEaseFactor = (current.easeFactor - 0.15).clamp(
          SpacedRepetitionConfig.minEaseFactor,
          SpacedRepetitionConfig.maxEaseFactor,
        );
        
        if (current.state == 'NEW' || current.state == 'LEARNING') {
          newState = 'LEARNING';
          newInterval = SpacedRepetitionConfig.learningSteps.length > 1 
              ? SpacedRepetitionConfig.learningSteps[1] 
              : SpacedRepetitionConfig.learningSteps.first;
        } else {
          newState = 'REVIEW';
          newInterval = (current.interval * 1.2).clamp(0, 1440).round(); // min 1 nap
        }
        break;

      case 'Good':
        if (current.state == 'NEW' || current.state == 'LEARNING') {
          // Learning steps végén graduation
          final currentStepIndex = SpacedRepetitionConfig.learningSteps.indexOf(current.interval);
          if (currentStepIndex < SpacedRepetitionConfig.learningSteps.length - 1) {
            newState = 'LEARNING';
            newInterval = SpacedRepetitionConfig.learningSteps[currentStepIndex + 1];
          } else {
            newState = 'REVIEW';
            newInterval = 4 * 24 * 60; // 4 nap
            newRepetitions = current.repetitions + 1;
          }
        } else {
          newState = 'REVIEW';
          newInterval = (current.interval * current.easeFactor).round();
          newRepetitions = current.repetitions + 1;
        }
        break;

      case 'Easy':
        newEaseFactor = (current.easeFactor + 0.15).clamp(
          SpacedRepetitionConfig.minEaseFactor,
          SpacedRepetitionConfig.maxEaseFactor,
        );
        
        if (current.state == 'NEW' || current.state == 'LEARNING') {
          newState = 'REVIEW';
          newInterval = (4 * 24 * 60 * SpacedRepetitionConfig.easyBonus).round(); // 4 nap * easyBonus
          newRepetitions = current.repetitions + 1;
        } else {
          newState = 'REVIEW';
          newInterval = (current.interval * current.easeFactor * SpacedRepetitionConfig.easyBonus).round();
          newRepetitions = current.repetitions + 1;
        }
        break;
    }

    // Intervallum korlát
    newInterval = newInterval.clamp(0, SpacedRepetitionConfig.maxInterval);

    final nextReview = Timestamp.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch + (newInterval * 60 * 1000),
    );

    return current.copyWith(
      state: newState,
      interval: newInterval,
      easeFactor: newEaseFactor,
      repetitions: newRepetitions,
      lastReview: now,
      nextReview: nextReview,
      lastRating: rating,
    );
  }

  /// Deck snapshot frissítése
  static Future<void> _updateDeckSnapshot(
    String deckId,
    String cardIndex,
    String newRating,
    String oldRating,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('deck_stats')
          .doc(deckId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        final current = doc.exists 
            ? DeckStats.fromMap(doc.data()!)
            : DeckStats(
                again: 0,
                hard: 0,
                good: 0,
                easy: 0,
                ratings: {},
                updatedAt: Timestamp.now(),
              );

        // Előző rating kivonása
        final updatedRatings = Map<String, String>.from(current.ratings);
        if (oldRating != 'Again' && updatedRatings.containsKey(cardIndex)) {
          updatedRatings.remove(cardIndex);
        }

        // Új rating hozzáadása
        if (newRating != 'Again') {
          updatedRatings[cardIndex] = newRating;
        }

        // Számlálók frissítése
        int again = current.again;
        int hard = current.hard;
        int good = current.good;
        int easy = current.easy;

        // Előző rating kivonása
        switch (oldRating) {
          case 'Again': again = (again - 1).clamp(0, double.infinity).toInt(); break;
          case 'Hard': hard = (hard - 1).clamp(0, double.infinity).toInt(); break;
          case 'Good': good = (good - 1).clamp(0, double.infinity).toInt(); break;
          case 'Easy': easy = (easy - 1).clamp(0, double.infinity).toInt(); break;
        }

        // Új rating hozzáadása
        switch (newRating) {
          case 'Again': again++; break;
          case 'Hard': hard++; break;
          case 'Good': good++; break;
          case 'Easy': easy++; break;
        }

        final updatedStats = DeckStats(
          again: again,
          hard: hard,
          good: good,
          easy: easy,
          ratings: updatedRatings,
          updatedAt: Timestamp.now(),
        );

        transaction.set(docRef, updatedStats.toMap());
      });

    } catch (e) {
      print('Error updating deck snapshot: $e');
    }
  }

  /// Kategória statisztikák frissítése
  static Future<void> _updateCategoryStats(
    String categoryId,
    String newRating,
    String oldRating,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Csak akkor frissítjük, ha változás történt
      if (newRating == oldRating) return;

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('category_stats')
          .doc(categoryId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        final current = doc.exists 
            ? CategoryStats.fromMap(doc.data()!)
            : CategoryStats(
                againCount: 0,
                hardCount: 0,
                updatedAt: Timestamp.now(),
              );

        int againCount = current.againCount;
        int hardCount = current.hardCount;

        // Előző rating kivonása
        switch (oldRating) {
          case 'Again': againCount = (againCount - 1).clamp(0, double.infinity).toInt(); break;
          case 'Hard': hardCount = (hardCount - 1).clamp(0, double.infinity).toInt(); break;
        }

        // Új rating hozzáadása
        switch (newRating) {
          case 'Again': againCount++; break;
          case 'Hard': hardCount++; break;
        }

        final updatedStats = CategoryStats(
          againCount: againCount,
          hardCount: hardCount,
          updatedAt: Timestamp.now(),
        );

        transaction.set(docRef, updatedStats.toMap());
      });

    } catch (e) {
      print('Error updating category stats: $e');
    }
  }

  /// Deck cache invalidálása
  static void _invalidateDeckCache(String deckId) {
    _dueCardsCache.remove(deckId);
    _cacheTimestamps.remove(deckId);
  }
}

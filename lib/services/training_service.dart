import '../models/vocabulary.dart';
import '../models/vocabulary_stack.dart';
import 'firestore_service.dart';

class TrainingService {
  final FirestoreService _firestoreService;

  TrainingService(this._firestoreService);

  /// Baut eine Trainings-Session aus Training + Review Stapel.
  List<Vocabulary> buildSession(List<Vocabulary> allVocabs, int count) {
    final training = allVocabs
        .where((v) => v.stack == VocabularyStack.training)
        .toList();
    final review = allVocabs
        .where((v) => v.stack == VocabularyStack.review)
        .toList();

    // Priorisiere Review-Wörter, dann Training
    final combined = [...review, ...training];
    combined.shuffle();
    return combined.take(count).toList();
  }

  /// Richtig: training → review, review → mastered
  Future<void> markCorrect(String uid, Vocabulary vocab) async {
    final nextStack = switch (vocab.stack) {
      VocabularyStack.training => VocabularyStack.review,
      VocabularyStack.review => VocabularyStack.mastered,
      _ => vocab.stack,
    };
    if (nextStack != vocab.stack) {
      await _firestoreService.moveToStack(uid, vocab.languagePairId, vocab.id, nextStack);
    }
  }

  /// Falsch: review → training, training bleibt training
  Future<void> markWrong(String uid, Vocabulary vocab) async {
    if (vocab.stack == VocabularyStack.review) {
      await _firestoreService.moveToStack(uid, vocab.languagePairId, vocab.id, VocabularyStack.training);
    }
  }
}

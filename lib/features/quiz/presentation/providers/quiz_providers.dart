import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/quiz_repository.dart';
import '../../domain/models/question.dart';

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => const QuizRepository(),
);

final questionsProvider = FutureProvider<List<Question>>((ref) {
  return ref.watch(quizRepositoryProvider).fetchQuestions();
});

class QuizState {
  const QuizState({
    this.currentIndex = 0,
    this.score = 0,
    this.selectedOptionIndex,
    this.isFinished = false,
  });

  final int currentIndex;
  final int score;
  final int? selectedOptionIndex;
  final bool isFinished;

  QuizState copyWith({
    int? currentIndex,
    int? score,
    int? selectedOptionIndex,
    bool clearSelection = false,
    bool? isFinished,
  }) {
    return QuizState(
      currentIndex: currentIndex ?? this.currentIndex,
      score: score ?? this.score,
      selectedOptionIndex:
          clearSelection ? null : selectedOptionIndex ?? this.selectedOptionIndex,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

class QuizController extends Notifier<QuizState> {
  @override
  QuizState build() => const QuizState();

  void selectOption(int optionIndex) {
    if (state.isFinished || state.selectedOptionIndex != null) return;
    state = state.copyWith(selectedOptionIndex: optionIndex);
  }

  void nextQuestion(List<Question> questions) {
    final selectedIndex = state.selectedOptionIndex;
    if (selectedIndex == null || questions.isEmpty) return;

    final question = questions[state.currentIndex];
    final nextScore = state.score + (question.isCorrect(selectedIndex) ? 1 : 0);
    final isLastQuestion = state.currentIndex == questions.length - 1;

    state = state.copyWith(
      currentIndex: isLastQuestion ? state.currentIndex : state.currentIndex + 1,
      score: nextScore,
      clearSelection: true,
      isFinished: isLastQuestion,
    );
  }

  void restart() {
    state = const QuizState();
  }
}

final quizControllerProvider = NotifierProvider<QuizController, QuizState>(
  QuizController.new,
);

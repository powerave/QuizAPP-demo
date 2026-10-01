import '../../domain/models/question.dart';

class QuizRepository {
  const QuizRepository();

  Future<List<Question>> fetchQuestions() async {
    return const [
      Question(
        id: 'flutter-1',
        text: 'Quel langage est utilisé pour développer Flutter ?',
        options: ['Dart', 'Kotlin', 'Swift', 'JavaScript'],
        correctOptionIndex: 0,
      ),
      Question(
        id: 'flutter-2',
        text: 'Quel widget possède un état mutable ?',
        options: ['StatelessWidget', 'StatefulWidget', 'InheritedWidget', 'Text'],
        correctOptionIndex: 1,
      ),
    ];
  }
}

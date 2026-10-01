class Question {
  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctOptionIndex,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctOptionIndex;

  bool isCorrect(int selectedOptionIndex) =>
      selectedOptionIndex == correctOptionIndex;
}

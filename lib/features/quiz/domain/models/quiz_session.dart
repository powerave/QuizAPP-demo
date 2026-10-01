import '../../../../core/config/app_config.dart';

class QuizSession {
  const QuizSession({
    this.serverUrl = AppConfig.quizServerUrl,
    this.roomId = '',
    this.playerName = '',
    this.isConnecting = false,
    this.isConnected = false,
    this.isJoined = false,
    this.isFinished = false,
    this.questionIndex = 0,
    this.totalQuestions = 0,
    this.playerCount = 0,
    this.answeredCount = 0,
    this.questionText,
    this.options = const [],
    this.selectedOptionIndex,
    this.scores = const {},
    this.availableRooms = const [],
    this.isLoadingRooms = false,
    this.error,
  });

  final String serverUrl;
  final String roomId;
  final String playerName;
  final bool isConnecting;
  final bool isConnected;
  final bool isJoined;
  final bool isFinished;
  final int questionIndex;
  final int totalQuestions;
  final int playerCount;
  final int answeredCount;
  final String? questionText;
  final List<String> options;
  final int? selectedOptionIndex;
  final Map<String, int> scores;
  final List<RoomSummary> availableRooms;
  final bool isLoadingRooms;
  final String? error;

  bool get isWaiting => isJoined && !isFinished && questionText == null;

  QuizSession copyWith({
    String? serverUrl,
    String? roomId,
    String? playerName,
    bool? isConnecting,
    bool? isConnected,
    bool? isJoined,
    bool? isFinished,
    int? questionIndex,
    int? totalQuestions,
    int? playerCount,
    int? answeredCount,
    String? questionText,
    bool clearQuestion = false,
    List<String>? options,
    int? selectedOptionIndex,
    bool clearSelection = false,
    Map<String, int>? scores,
    List<RoomSummary>? availableRooms,
    bool? isLoadingRooms,
    String? error,
    bool clearError = false,
  }) {
    return QuizSession(
      serverUrl: serverUrl ?? this.serverUrl,
      roomId: roomId ?? this.roomId,
      playerName: playerName ?? this.playerName,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      isJoined: isJoined ?? this.isJoined,
      isFinished: isFinished ?? this.isFinished,
      questionIndex: questionIndex ?? this.questionIndex,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      playerCount: playerCount ?? this.playerCount,
      answeredCount: answeredCount ?? this.answeredCount,
      questionText: clearQuestion ? null : questionText ?? this.questionText,
      options: options ?? this.options,
      selectedOptionIndex:
          clearSelection ? null : selectedOptionIndex ?? this.selectedOptionIndex,
      scores: scores ?? this.scores,
      availableRooms: availableRooms ?? this.availableRooms,
      isLoadingRooms: isLoadingRooms ?? this.isLoadingRooms,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class RoomSummary {
  const RoomSummary({
    required this.roomId,
    required this.playerCount,
    required this.capacity,
  });

  final String roomId;
  final int playerCount;
  final int capacity;
}

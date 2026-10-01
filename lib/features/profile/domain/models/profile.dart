class Profile {
  const Profile({
    this.profileId = '',
    this.authToken = '',
    this.username = '',
    this.displayName = '',
    this.isLoading = true,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.totalScore = 0,
    this.history = const [],
  });

  final String profileId;
  final String authToken;
  final String username;
  final String displayName;
  final bool isLoading;
  final int gamesPlayed;
  final int wins;
  final int totalScore;
  final List<GameHistory> history;

  bool get isConfigured => profileId.isNotEmpty && displayName.trim().isNotEmpty;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  int get averageScore => gamesPlayed == 0 ? 0 : (totalScore / gamesPlayed).round();

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      profileId: json['profileId'] as String? ?? '',
      authToken: json['authToken'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      isLoading: false,
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      totalScore: json['totalScore'] as int? ?? 0,
      history: List<GameHistory>.from(
        (json['history'] as List? ?? const []).map(
          (item) => GameHistory.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
    );
  }

  Profile copyWith({
    String? profileId,
    String? authToken,
    String? username,
    String? displayName,
    bool? isLoading,
    int? gamesPlayed,
    int? wins,
    int? totalScore,
    List<GameHistory>? history,
  }) {
    return Profile(
      profileId: profileId ?? this.profileId,
      authToken: authToken ?? this.authToken,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      isLoading: isLoading ?? this.isLoading,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      totalScore: totalScore ?? this.totalScore,
      history: history ?? this.history,
    );
  }
}

class GameHistory {
  const GameHistory({
    required this.playedAt,
    required this.score,
    required this.totalQuestions,
    required this.opponent,
    required this.won,
  });

  final DateTime playedAt;
  final int score;
  final int totalQuestions;
  final String opponent;
  final bool won;

  factory GameHistory.fromJson(Map<String, dynamic> json) {
    return GameHistory(
      playedAt: DateTime.parse(json['playedAt'] as String),
      score: json['score'] as int,
      totalQuestions: json['totalQuestions'] as int,
      opponent: json['opponent'] as String,
      won: json['won'] as bool,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quizapp/features/profile/domain/models/profile.dart';
import 'package:quizapp/features/profile/data/repositories/profile_repository.dart';
import 'package:quizapp/features/profile/presentation/providers/profile_provider.dart';

void main() {
  test('met à jour le nom et les statistiques du profil', () async {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_TestProfileRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(profileProvider).displayName, '');

    await container.read(profileProvider.notifier).updateDisplayName('Nina');
    container.read(profileProvider.notifier).addGame(
          GameHistory(
            playedAt: DateTime(2026, 9, 25),
            score: 5,
            totalQuestions: 5,
            opponent: 'Sam',
            won: true,
          ),
        );

    final profile = container.read(profileProvider);
    expect(profile.displayName, 'Nina');
    expect(profile.gamesPlayed, 1);
    expect(profile.wins, 1);
    expect(profile.history.first.opponent, 'Sam');
  });
}

class _TestProfileRepository extends ProfileRepository {
  Profile current = const Profile(isLoading: false);

  @override
  Profile get profile => current;

  @override
  Future<Profile> load() async => current;

  @override
  Future<Profile> updateDisplayName(String displayName) async {
    current = current.copyWith(displayName: displayName, isLoading: false);
    return current;
  }

  @override
  Profile addGame(GameHistory game) {
    current = current.copyWith(
      gamesPlayed: current.gamesPlayed + 1,
      wins: current.wins + (game.won ? 1 : 0),
      totalScore: current.totalScore + game.score,
      history: [game, ...current.history],
    );
    return current;
  }
}

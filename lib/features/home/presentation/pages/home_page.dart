import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/domain/models/profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/pages/profile_entry_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({
    required this.onJoinQuiz,
    required this.onCreateQuiz,
    required this.onOpenProfile,
    super.key,
  });

  final VoidCallback onJoinQuiz;
  final VoidCallback onCreateQuiz;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salut ${profile.displayName}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Prêt à mettre ton savoir à l’épreuve ?'),
                ],
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: Text(profile.initials),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Se déconnecter',
              onPressed: () async {
                await ref.read(profileProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/entry');
                }
              },
            )
          ],
        ),
        const SizedBox(height: 28),
        _HeroPanel(onJoinQuiz: onJoinQuiz, onCreateQuiz: onCreateQuiz),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ton rythme', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: onOpenProfile,
              child: const Text('Voir le profil'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _HomeStats(profile: profile),
        const SizedBox(height: 28),
        Text('Dernières parties', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (profile.history.isEmpty)
          const Text('Rejoins une partie pour commencer ton historique.')
        else
          for (final game in profile.history.take(2))
            _RecentGame(
              opponent: game.opponent,
              score: '${game.score}/${game.totalQuestions}',
              result: game.won ? 'Victoire' : 'À retenter',
              won: game.won,
            ),
      ],
    );
  }

}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onJoinQuiz, required this.onCreateQuiz});

  final VoidCallback onJoinQuiz;
  final VoidCallback onCreateQuiz;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, color: colorScheme.tertiary, size: 30),
          const SizedBox(height: 18),
          Text(
            'Le bon moment\npour jouer.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Un salon, deux joueurs, une question à la fois.',
            style: TextStyle(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onJoinQuiz,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Rejoindre une partie'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onCreateQuiz,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onPrimaryContainer,
              side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Créer une partie'),
          ),
        ],
      ),
    );
  }

}

class _HomeStats extends StatelessWidget {
  const _HomeStats({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Metric(value: '${profile.wins}', label: 'Victoires')),
        const SizedBox(width: 10),
        Expanded(child: _Metric(value: '${profile.gamesPlayed}', label: 'Parties')),
        const SizedBox(width: 10),
        Expanded(child: _Metric(value: '${profile.averageScore}', label: 'Moyenne')),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFFE1E7E4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RecentGame extends StatelessWidget {
  const _RecentGame({
    required this.opponent,
    required this.score,
    required this.result,
    required this.won,
  });

  final String opponent;
  final String score;
  final String result;
  final bool won;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(won ? Icons.emoji_events_outlined : Icons.refresh),
      title: Text('Contre $opponent'),
      subtitle: Text(result),
      trailing: Text(score, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

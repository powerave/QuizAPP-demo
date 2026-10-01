import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/profile.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text('Ton profil', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Garde un œil sur tes parties et ton évolution.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _ProfileHeader(profile: profile),
        const SizedBox(height: 24),
        Text('Identité', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: Text(profile.displayName),
          subtitle: Text('@${profile.username}'),
        ),
        const SizedBox(height: 28),
        Text('Statistiques', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _StatsGrid(profile: profile),
        const SizedBox(height: 28),
        Text('Historique récent', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (profile.history.isEmpty)
          const Text('Tes premières parties apparaîtront ici.')
        else
          for (final game in profile.history) _HistoryTile(game: game),
      ],
    );
  }

}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: Text(profile.initials, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${profile.gamesPlayed} parties jouées'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatItem(value: '${profile.wins}', label: 'Victoires')),
        const SizedBox(width: 12),
        Expanded(child: _StatItem(value: '${profile.averageScore}', label: 'Score moyen')),
        const SizedBox(width: 12),
        Expanded(child: _StatItem(value: '${profile.totalScore}', label: 'Points')),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.game});

  final GameHistory game;

  @override
  Widget build(BuildContext context) {
    final color = game.won
      ? Theme.of(context).colorScheme.tertiary
      : Theme.of(context).colorScheme.onSurfaceVariant;
    final date = '${game.playedAt.day.toString().padLeft(2, '0')}/'
        '${game.playedAt.month.toString().padLeft(2, '0')}/${game.playedAt.year}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(game.won ? Icons.emoji_events_outlined : Icons.sports_score_outlined),
      title: Text(game.won ? 'Victoire contre ${game.opponent}' : 'Partie contre ${game.opponent}'),
      subtitle: Text(date),
      trailing: Text(
        '${game.score}/${game.totalQuestions}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

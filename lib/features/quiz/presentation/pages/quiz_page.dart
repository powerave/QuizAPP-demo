import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/quiz_session.dart';
import '../providers/multiplayer_provider.dart';

enum QuizLobbyMode { join, create }

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({this.initialMode = QuizLobbyMode.join, super.key});

  final QuizLobbyMode initialMode;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  QuizLobbyMode mode = QuizLobbyMode.join;
  Timer? _roomsRefreshTimer;

  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
    _updateRoomsRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant QuizPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      setState(() => mode = widget.initialMode);
      _updateRoomsRefreshTimer();
    }
  }

  @override
  void dispose() {
    _roomsRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(multiplayerProvider, (previous, next) {
      if (next.isJoined) {
        _roomsRefreshTimer?.cancel();
        _roomsRefreshTimer = null;
      } else if (mode == QuizLobbyMode.join &&
          previous?.isJoined == true &&
          mounted) {
        _updateRoomsRefreshTimer();
      }
    });
    final session = ref.watch(multiplayerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('QuizAPP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: session.isJoined
            ? _GameView(session: session)
            : _LobbyView(
                mode: mode,
                session: session,
                onRefresh: _refreshRooms,
                onCreate: _createRoom,
                onJoin: _joinRoom,
                onShowCreate: () => context.go('/quiz/create'),
                onShowJoin: () {
                  context.go('/quiz');
                },
              ),
      ),
    );
  }

  void _refreshRooms() {
    if (ref.read(multiplayerProvider).isLoadingRooms) return;
    ref.read(multiplayerProvider.notifier).listRooms(
          serverUrl: ref.read(multiplayerProvider).serverUrl,
        );
  }

  void _updateRoomsRefreshTimer() {
    _roomsRefreshTimer?.cancel();
    _roomsRefreshTimer = null;
    if (mode != QuizLobbyMode.join || ref.read(multiplayerProvider).isJoined) {
      return;
    }

    _roomsRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted || mode != QuizLobbyMode.join) return;
        final session = ref.read(multiplayerProvider);
        if (!session.isJoined && !session.isLoadingRooms) {
          _refreshRooms();
        }
      },
    );
  }

  void _createRoom() {
    ref.read(multiplayerProvider.notifier).create(
          serverUrl: ref.read(multiplayerProvider).serverUrl,
        );
  }

  void _joinRoom(String roomId) {
    ref.read(multiplayerProvider.notifier).join(
          serverUrl: ref.read(multiplayerProvider).serverUrl,
          roomId: roomId,
        );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.mode,
    required this.session,
    required this.onRefresh,
    required this.onCreate,
    required this.onJoin,
    required this.onShowCreate,
    required this.onShowJoin,
  });

  final QuizLobbyMode mode;
  final QuizSession session;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<String> onJoin;
  final VoidCallback onShowCreate;
  final VoidCallback onShowJoin;

  @override
  Widget build(BuildContext context) {
    final isCreate = mode == QuizLobbyMode.create;
    return ListView(
      children: [
        Text(
          isCreate ? 'Créer une partie' : 'Rejoindre une partie',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          isCreate
              ? 'Lance un salon et attends ton adversaire.'
              : 'Choisis un salon ouvert pour entrer dans la partie.',
        ),
        const SizedBox(height: 24),
        SegmentedButton<QuizLobbyMode>(
          segments: const [
            ButtonSegment(value: QuizLobbyMode.join, label: Text('Rejoindre')),
            ButtonSegment(value: QuizLobbyMode.create, label: Text('Créer')),
          ],
          selected: {mode},
          onSelectionChanged: (selection) {
            if (selection.single == QuizLobbyMode.create) {
              onShowCreate();
            } else {
              onShowJoin();
            }
          },
        ),
        const SizedBox(height: 24),
        if (isCreate)
          _CreateRoomPanel(
            isCreating: session.isConnecting,
            onCreate: onCreate,
          )
        else
          _AvailableRooms(
            rooms: session.availableRooms,
            isLoading: session.isLoadingRooms,
            onRefresh: onRefresh,
            onJoin: onJoin,
          ),
        if (session.error != null) ...[
          const SizedBox(height: 16),
          Text(
            session.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _CreateRoomPanel extends StatelessWidget {
  const _CreateRoomPanel({required this.isCreating, required this.onCreate});

  final bool isCreating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.add_circle_outline,
          size: 42,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 16),
        const Text('Tu seras le premier joueur du salon.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: isCreating ? null : onCreate,
          icon: isCreating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(isCreating ? 'Création...' : 'Créer le salon'),
        ),
      ],
    );
  }
}

class _AvailableRooms extends StatelessWidget {
  const _AvailableRooms({
    required this.rooms,
    required this.isLoading,
    required this.onRefresh,
    required this.onJoin,
  });

  final List<RoomSummary> rooms;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<String> onJoin;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rooms.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 30),
          Icon(
            Icons.meeting_room_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('Aucun salon disponible.'),
          const SizedBox(height: 6),
          const Text('Crée une partie pour lancer un nouveau salon.'),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser'),
          ),
        ],
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: onRefresh,
            tooltip: 'Actualiser les salons',
            icon: const Icon(Icons.refresh),
          ),
        ),
        for (final room in rooms)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text('Salon ${room.roomId}'),
            subtitle: Text('${room.playerCount} / ${room.capacity} joueur(s)'),
            trailing: FilledButton(
              onPressed: () => onJoin(room.roomId),
              child: const Text('Rejoindre'),
            ),
          ),
      ],
    );
  }
}

class _GameView extends ConsumerWidget {
  const _GameView({required this.session});

  final QuizSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.isFinished) return _ResultView(scores: session.scores);
    if (session.isWaiting) {
      return Center(
        child: Text(
          'Salon ${session.roomId}\nEn attente du deuxième joueur...\n'
          '${session.playerCount} / 2 connecté(s)',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(
      children: [
        Text('Question ${session.questionIndex + 1} / ${session.totalQuestions}'),
        const SizedBox(height: 24),
        Text(session.questionText ?? '', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        RadioGroup<int>(
          groupValue: session.selectedOptionIndex,
          onChanged: (value) {
            if (value != null) ref.read(multiplayerProvider.notifier).answer(value);
          },
          child: Column(
            children: [
              for (var index = 0; index < session.options.length; index++)
                RadioListTile<int>(value: index, title: Text(session.options[index])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('${session.answeredCount} / ${session.playerCount} réponse(s) reçue(s)'),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.scores});

  final Map<String, int> scores;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Partie terminée', style: Theme.of(context).textTheme.headlineSmall),
          for (final entry in scores.entries) Text('${entry.key} : ${entry.value} point(s)'),
        ],
      ),
    );
  }
}

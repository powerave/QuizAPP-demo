import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/multiplayer_service.dart';
import '../../domain/models/quiz_session.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final multiplayerProvider =
    NotifierProvider<MultiplayerController, QuizSession>(MultiplayerController.new);

class MultiplayerController extends Notifier<QuizSession> {
  late final MultiplayerService _service;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  QuizSession build() {
    _service = MultiplayerService();
    ref.onDispose(() {
      _subscription?.cancel();
      _service.dispose();
    });
    return const QuizSession();
  }

  Future<void> _ensureConnected({required String serverUrl}) async {
    if (state.isConnected) return;
    state = state.copyWith(
      serverUrl: serverUrl,
      isConnecting: true,
      clearError: true,
    );

    try {
      await _service.connect(Uri.parse(serverUrl));
      _subscription = _service.messages.listen(
        _handleMessage,
        onError: (Object error) {
          state = state.copyWith(
            isConnecting: false,
            isConnected: false,
            error: 'Connexion interrompue : $error',
          );
        },
        onDone: () {
          state = state.copyWith(isConnected: false, isConnecting: false);
        },
      );
      state = state.copyWith(isConnecting: false, isConnected: true);
    } catch (error) {
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        error: 'Impossible de joindre le serveur : $error',
      );
    }
  }

  Future<void> listRooms({required String serverUrl}) async {
    state = state.copyWith(isLoadingRooms: true, clearError: true);
    try {
      await _ensureConnected(serverUrl: serverUrl);
      final profile = ref.read(profileProvider);
      _service.listRooms(
        profileId: profile.profileId,
        authToken: profile.authToken,
      );
    } catch (_) {
      state = state.copyWith(isLoadingRooms: false);
    }
  }

  Future<void> create({required String serverUrl}) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      await _ensureConnected(serverUrl: serverUrl);
      final profile = ref.read(profileProvider);
      _service.create(
        playerName: profile.displayName,
        profileId: profile.profileId,
        authToken: profile.authToken,
      );
    } catch (_) {
      state = state.copyWith(isConnecting: false);
    }
  }

  Future<void> join({required String serverUrl, required String roomId}) async {
    state = state.copyWith(
      roomId: roomId,
      isConnecting: true,
      clearError: true,
    );
    try {
      await _ensureConnected(serverUrl: serverUrl);
      final profile = ref.read(profileProvider);
      _service.join(
        roomId: roomId,
        playerName: profile.displayName,
        profileId: profile.profileId,
        authToken: profile.authToken,
      );
    } catch (_) {
      state = state.copyWith(isConnecting: false);
    }
  }

  void answer(int optionIndex) {
    if (state.selectedOptionIndex != null || state.isFinished) return;
    state = state.copyWith(selectedOptionIndex: optionIndex);
    _service.answer(optionIndex);
  }

  void _handleMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'waiting':
        state = state.copyWith(
          isJoined: true,
          isConnecting: false,
          roomId: message['roomId'] as String? ?? state.roomId,
          playerCount: message['playerCount'] as int,
          clearQuestion: true,
          clearSelection: true,
        );
      case 'rooms':
        state = state.copyWith(
          isLoadingRooms: false,
          availableRooms: (message['rooms'] as List? ?? const [])
              .map((room) => RoomSummary(
                    roomId: room['roomId'] as String,
                    playerCount: room['playerCount'] as int,
                    capacity: room['capacity'] as int,
                  ))
              .toList(),
        );
      case 'room_created':
        state = state.copyWith(
          roomId: message['roomId'] as String,
          isConnecting: false,
        );
      case 'question':
        state = state.copyWith(
          isJoined: true,
          isFinished: false,
          questionIndex: message['questionIndex'] as int,
          totalQuestions: message['totalQuestions'] as int,
          playerCount: message['playerCount'] as int,
          answeredCount: 0,
          questionText: message['text'] as String,
          options: List<String>.from(message['options'] as List),
          clearSelection: true,
          scores: _readScores(message['scores']),
        );
      case 'progress':
        state = state.copyWith(
          answeredCount: message['answeredCount'] as int,
          playerCount: message['playerCount'] as int,
          scores: _readScores(message['scores']),
        );
      case 'finished':
        final serverProfile = message['profile'];
        if (serverProfile is Map) {
          ref.read(profileProvider.notifier).syncFromServer(
                Map<String, dynamic>.from(serverProfile),
              );
        }
        state = state.copyWith(
          isFinished: true,
          answeredCount: message['playerCount'] as int,
          playerCount: message['playerCount'] as int,
          scores: _readScores(message['scores']),
        );
      case 'error':
        state = state.copyWith(
          isConnecting: false,
          isLoadingRooms: false,
          error: message['message'] as String,
        );
    }
  }

  Map<String, int> _readScores(Object? rawScores) {
    return Map<String, int>.from(
      (rawScores as Map).map(
        (key, value) => MapEntry(key.toString(), value as int),
      ),
    );
  }
}

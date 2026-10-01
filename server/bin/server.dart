import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'profile_store.dart';

const questions = [
  {
    'text': 'Quel langage est utilisé pour développer Flutter ?',
    'options': ['Dart', 'Kotlin', 'Swift', 'JavaScript'],
    'correctOptionIndex': 0,
  },
  {
    'text': 'Quel widget possède un état mutable ?',
    'options': ['StatelessWidget', 'StatefulWidget', 'InheritedWidget', 'Text'],
    'correctOptionIndex': 1,
  },
];

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final allowedOrigins = (Platform.environment['ALLOWED_ORIGINS'] ??
          'http://localhost:8081,http://127.0.0.1:8081')
      .split(',')
      .map((origin) => origin.trim())
      .where((origin) => origin.isNotEmpty)
      .toSet();
  final store = ProfileStore(
    redisHost: Platform.environment['REDIS_HOST'] ?? '127.0.0.1',
    redisPort: int.tryParse(Platform.environment['REDIS_PORT'] ?? '') ?? 6379,
    redisPassword: Platform.environment['REDIS_PASSWORD'],
    postgresHost: Platform.environment['POSTGRES_HOST'] ?? '127.0.0.1',
    postgresPort:
        int.tryParse(Platform.environment['POSTGRES_PORT'] ?? '') ?? 5432,
    postgresDatabase: Platform.environment['POSTGRES_DB'] ?? 'quizapp',
    postgresUsername: Platform.environment['POSTGRES_USER'] ?? 'quizapp',
    postgresPassword: Platform.environment['POSTGRES_PASSWORD'] ?? 'quizapp',
  );
  await store.verifyConnection();
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  final rooms = <String, QuizRoom>{};

  stdout.writeln('QuizAPP server listening on 0.0.0.0:$port');
  await for (final request in server) {
    if (!_isOriginAllowed(request, allowedOrigins)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Origin not allowed');
      await request.response.close();
      continue;
    }
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      unawaited(_handleConnection(request, rooms, store));
    } else if (request.method == 'POST' && request.uri.path == '/auth') {
      await _handleAuth(request, store, allowedOrigins);
    } else if (request.method == 'GET' && request.uri.path == '/profile') {
      await _handleProfile(request, store, allowedOrigins);
    } else if (request.uri.path == '/health') {
      _addCorsHeaders(request, allowedOrigins);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write('{"status":"ok"}');
      await request.response.close();
    } else if (request.method == 'OPTIONS') {
      _addCorsHeaders(request, allowedOrigins);
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    } else {
      _addCorsHeaders(request, allowedOrigins);
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('QuizAPP WebSocket server');
      await request.response.close();
    }
  }
}

Future<void> _handleAuth(
  HttpRequest request,
  ProfileStore store,
  Set<String> allowedOrigins,
) async {
  _addCorsHeaders(request, allowedOrigins);
  try {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final profile = await store.authenticate(
      username: payload['username'] as String? ?? '',
      password: payload['password'] as String? ?? '',
      profileId: payload['profileId'] as String? ?? '',
      displayName: payload['displayName'] as String?,
      createAccount: payload['createAccount'] as bool? ?? false,
    );
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(profile.toJson()));
  } on StateError catch (error) {
    final message = error.message;
    request.response
      ..statusCode = message.contains('déjà utilisé')
          ? HttpStatus.conflict
          : HttpStatus.unauthorized
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': message}));
  } catch (error, stackTrace) {
    stderr.writeln('DEBUG: Auth error: $error\n$stackTrace');
    request.response
      ..statusCode = HttpStatus.badRequest
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': 'Requête d’authentification invalide.'}));
  } finally {
    await request.response.close();
  }
}

Future<void> _handleProfile(
  HttpRequest request,
  ProfileStore store,
  Set<String> allowedOrigins,
) async {
  _addCorsHeaders(request, allowedOrigins);
  final authorization = request.headers.value(HttpHeaders.authorizationHeader);
  final token = authorization != null && authorization.startsWith('Bearer ')
      ? authorization.substring('Bearer '.length).trim()
      : '';
  final profile = await store.getForSession(token);
  if (profile == null) {
    request.response
      ..statusCode = HttpStatus.unauthorized
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': 'Authentification requise.'}));
  } else {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(profile.toJson()));
  }
  await request.response.close();
}

bool _isOriginAllowed(HttpRequest request, Set<String> allowedOrigins) {
  final origin = request.headers.value('origin');
  return origin == null || origin.isEmpty || allowedOrigins.contains(origin);
}

void _addCorsHeaders(HttpRequest request, Set<String> allowedOrigins) {
  final origin = request.headers.value('origin');
  final response = request.response;
  response.headers
    ..set(
      'Access-Control-Allow-Origin',
      allowedOrigins.contains(origin) ? origin! : allowedOrigins.first,
    )
    ..set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type, Authorization')
    ..set('Vary', 'Origin');
}

Future<void> _handleConnection(
  HttpRequest request,
  Map<String, QuizRoom> rooms,
  ProfileStore store,
) async {
  final socket = await WebSocketTransformer.upgrade(request);
  QuizRoom? room;
  Player? player;

  try {
    await for (final rawMessage in socket) {
      final message = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final authToken = (message['authToken'] as String? ?? '').trim();

      if (message['type'] == 'list_rooms') {
        if (!store.isSessionValid(
            authToken, message['profileId'] as String? ?? '')) {
          _send(socket, _error('unauthorized', 'Authentification requise.'));
          continue;
        }
        if (room != null) {
          _send(socket,
              _error('already_in_room', 'Vous êtes déjà dans un salon.'));
        } else {
          _send(socket, {'type': 'rooms', 'rooms': _roomSummaries(rooms)});
        }
        continue;
      }

      if (message['type'] == 'create') {
        if (room != null) {
          _send(socket,
              _error('already_in_room', 'Vous êtes déjà dans un salon.'));
          continue;
        }
        final playerName = (message['playerName'] as String? ?? '').trim();
        final profileId = (message['profileId'] as String? ?? '').trim();
        if (playerName.isEmpty ||
            profileId.isEmpty ||
            !store.isSessionValid(authToken, profileId)) {
          _send(socket, _error('invalid_request', 'Pseudo et profil requis.'));
          continue;
        }
        try {
          final profile = await store.register(
            profileId: profileId,
            displayName: playerName,
            authToken: authToken,
          );
          final roomId = _newRoomId(rooms);
          final selectedRoom = QuizRoom(roomId, store);
          rooms[roomId] = selectedRoom;
          player = Player(socket, profile.profileId, profile.displayName);
          room = selectedRoom;
          room.add(player);
          _send(socket, {
            'type': 'room_created',
            'roomId': roomId,
            'playerCount': room.players.length,
          });
          room.broadcastState();
          _broadcastRoomLists(rooms);
        } catch (error) {
          _send(socket, _error('name_in_use', error.toString()));
        }
        continue;
      }

      if (message['type'] == 'join') {
        if (room != null) continue;

        final roomId = (message['roomId'] as String? ?? '').trim();
        final playerName = (message['playerName'] as String? ?? '').trim();
        final profileId = (message['profileId'] as String? ?? '').trim();
        if (roomId.isEmpty ||
            playerName.isEmpty ||
            profileId.isEmpty ||
            !store.isSessionValid(authToken, profileId)) {
          _send(socket,
              _error('invalid_request', 'Salon, pseudo et profil requis.'));
          continue;
        }

        final selectedRoom = rooms[roomId];
        if (selectedRoom == null) {
          _send(socket, _error('room_not_found', 'Salon introuvable.'));
          continue;
        }
        if (selectedRoom.players.length >= 2) {
          _send(socket, _error('room_full', 'Salon complet.'));
          continue;
        }
        if (selectedRoom.players.any((item) => item.name == playerName)) {
          _send(socket,
              _error('name_in_use', 'Pseudo déjà utilisé dans ce salon.'));
          continue;
        }

        try {
          final profile = await store.register(
            profileId: profileId,
            displayName: playerName,
            authToken: authToken,
          );
          player = Player(socket, profile.profileId, profile.displayName);
        } catch (error) {
          _send(socket, {'type': 'error', 'message': error.toString()});
          continue;
        }
        room = selectedRoom;
        room.add(player);
        room.broadcastState();
        _broadcastRoomLists(rooms);
        continue;
      }

      if (message['type'] == 'answer' && room != null && player != null) {
        final optionIndex = message['optionIndex'] as int?;
        if (optionIndex != null) await room.answer(player, optionIndex);
      }
    }
  } finally {
    if (room != null && player != null) {
      room.remove(player);
      room.broadcastState();
      if (room.players.isEmpty) {
        rooms.remove(room.id);
      }
      _broadcastRoomLists(rooms);
    }
    await socket.close();
  }
}

Map<String, Object?> _error(String code, String message) => {
      'type': 'error',
      'code': code,
      'message': message,
    };

String _newRoomId(Map<String, QuizRoom> rooms) {
  final random =
      DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
  final code = random.substring(random.length - 6);
  return rooms.containsKey(code) ? _newRoomId(rooms) : code;
}

List<Map<String, Object>> _roomSummaries(Map<String, QuizRoom> rooms) {
  return rooms.values
      .where((room) => room.players.isNotEmpty && room.players.length < 2)
      .map((room) => {
            'roomId': room.id,
            'playerCount': room.players.length,
            'capacity': 2,
          })
      .toList();
}

void _broadcastRoomLists(Map<String, QuizRoom> rooms) {
  final message = {'type': 'rooms', 'rooms': _roomSummaries(rooms)};
  for (final room in rooms.values) {
    room.broadcastToPlayers(message);
  }
}

void _send(WebSocket socket, Map<String, Object?> message) {
  socket.add(jsonEncode(message));
}

class Player {
  Player(this.socket, this.profileId, this.name);

  final WebSocket socket;
  final String profileId;
  final String name;
}

class QuizRoom {
  QuizRoom(this.id, this.store);

  final String id;
  final ProfileStore store;
  final players = <Player>[];
  final answers = <Player, int>{};
  final scores = <String, int>{};
  int questionIndex = 0;

  void add(Player player) {
    players.add(player);
    scores[player.name] = 0;
  }

  void remove(Player player) {
    players.remove(player);
    answers.remove(player);
    scores.remove(player.name);
  }

  Future<void> answer(Player player, int optionIndex) async {
    if (players.length < 2 || answers.containsKey(player)) return;
    if (optionIndex < 0 || optionIndex >= _options.length) return;

    answers[player] = optionIndex;
    if (answers.length == players.length) {
      await _finishQuestion();
    } else {
      _broadcast({
        'type': 'progress',
        'answeredCount': answers.length,
        'playerCount': players.length,
        'scores': scores,
      });
    }
  }

  void broadcastState() {
    unawaited(store.saveRoomMetadata(id, {
      'roomId': id,
      'questionIndex': questionIndex,
      'playerCount': players.length,
      'playerNames': players.map((player) => player.name).toList(),
      'scores': scores,
    }));
    if (players.length < 2) {
      _broadcast({
        'type': 'waiting',
        'roomId': id,
        'playerCount': players.length,
        'scores': scores,
      });
      return;
    }

    final question = questions[questionIndex];
    _broadcast({
      'type': 'question',
      'questionIndex': questionIndex,
      'totalQuestions': questions.length,
      'text': question['text'],
      'options': question['options'],
      'playerCount': players.length,
      'scores': scores,
    });
  }

  Future<void> _finishQuestion() async {
    final question = questions[questionIndex];
    final correctOptionIndex = question['correctOptionIndex'] as int;
    for (final entry in answers.entries) {
      if (entry.value == correctOptionIndex) {
        scores[entry.key.name] = (scores[entry.key.name] ?? 0) + 1;
      }
    }

    if (questionIndex == questions.length - 1) {
      for (final player in players) {
        final opponent = players.firstWhere((item) => item != player);
        final profile = await store.recordGame(
          profileId: player.profileId,
          opponent: opponent.name,
          score: scores[player.name] ?? 0,
          totalQuestions: questions.length,
          won: (scores[player.name] ?? 0) > (scores[opponent.name] ?? 0),
        );
        _send(player.socket, {
          'type': 'finished',
          'playerCount': players.length,
          'scores': scores,
          'profile': profile.toJson(),
        });
      }
      return;
    }

    questionIndex++;
    answers.clear();
    broadcastState();
  }

  void _broadcast(Map<String, Object?> message) {
    broadcastToPlayers(message);
  }

  void broadcastToPlayers(Map<String, Object?> message) {
    for (final player in List<Player>.from(players)) {
      _send(player.socket, message);
    }
  }

  List<String> get _options => List<String>.from(
        questions[questionIndex]['options'] as List,
      );
}

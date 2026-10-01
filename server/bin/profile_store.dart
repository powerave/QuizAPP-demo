import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

class ProfileRecord {
  const ProfileRecord({
    required this.profileId,
    required this.displayName,
    required this.gamesPlayed,
    required this.wins,
    required this.totalScore,
    required this.history,
    this.authToken = '',
  });

  final String profileId;
  final String displayName;
  final int gamesPlayed;
  final int wins;
  final int totalScore;
  final List<Map<String, dynamic>> history;
  final String authToken;

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'displayName': displayName,
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'totalScore': totalScore,
        'history': history,
        if (authToken.isNotEmpty) 'authToken': authToken,
      };

  ProfileRecord copyWith({String? authToken}) => ProfileRecord(
        profileId: profileId,
        displayName: displayName,
        gamesPlayed: gamesPlayed,
        wins: wins,
        totalScore: totalScore,
        history: history,
        authToken: authToken ?? this.authToken,
      );

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    return ProfileRecord(
      profileId: json['profileId'] as String,
      displayName: json['displayName'] as String,
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      totalScore: json['totalScore'] as int? ?? 0,
      history: List<Map<String, dynamic>>.from(
        (json['history'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
    );
  }
}

class ProfileStore {
  ProfileStore({
    required this.redisHost,
    required this.redisPort,
    this.redisPassword,
    required this.postgresHost,
    required this.postgresPort,
    required this.postgresDatabase,
    required this.postgresUsername,
    required this.postgresPassword,
  });

  final String redisHost;
  final int redisPort;
  final String? redisPassword;
  final String postgresHost;
  final int postgresPort;
  final String postgresDatabase;
  final String postgresUsername;
  final String postgresPassword;
  final _sessions = <String, String>{};

  Future<void> verifyConnection() async {
    final response = await _redisExecute(['PING']);
    if (response != 'PONG') {
      throw StateError('Redis did not answer PONG');
    }
    final connection = await _openPostgres();
    try {
      await connection.execute('''
        CREATE TABLE IF NOT EXISTS profiles (
          profile_id TEXT PRIMARY KEY,
          username TEXT,
          password_salt TEXT,
          password_hash TEXT,
          display_name TEXT NOT NULL,
          games_played INTEGER NOT NULL DEFAULT 0,
          wins INTEGER NOT NULL DEFAULT 0,
          total_score INTEGER NOT NULL DEFAULT 0,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      ''');
      await connection.execute(
        'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS username TEXT',
      );
      await connection.execute(
        'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_salt TEXT',
      );
      await connection.execute(
        'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash TEXT',
      );
      await connection.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_idx
        ON profiles (LOWER(username))
      ''');
      await connection.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS profiles_display_name_lower_idx
        ON profiles (LOWER(display_name))
      ''');
      await connection.execute('''
        CREATE TABLE IF NOT EXISTS game_history (
          id BIGSERIAL PRIMARY KEY,
          profile_id TEXT NOT NULL REFERENCES profiles(profile_id) ON DELETE CASCADE,
          played_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          score INTEGER NOT NULL,
          total_questions INTEGER NOT NULL,
          opponent TEXT NOT NULL,
          won BOOLEAN NOT NULL
        )
      ''');
      await connection.execute('''
        CREATE INDEX IF NOT EXISTS game_history_profile_played_idx
        ON game_history (profile_id, played_at DESC)
      ''');
    } finally {
      await connection.close();
    }
  }

  Future<ProfileRecord> authenticate({
    required String username,
    required String password,
    required String profileId,
    String? displayName,
    bool createAccount = false,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedDisplayName = displayName?.trim() ?? '';
    if (normalizedUsername.length < 3 || password.length < 8) {
      throw StateError('Identifiant ou mot de passe invalide.');
    }
    final connection = await _openPostgres();
    try {
      return await connection.runTx((session) async {
        final result = await session.execute(
          Sql.named(
              '''SELECT profile_id, username, password_salt, password_hash,
                    display_name, games_played, wins, total_score
             FROM profiles WHERE LOWER(username) = LOWER(@username)'''),
          parameters: {'username': normalizedUsername},
        );

        if (createAccount) {
          if (result.isNotEmpty) {
            throw StateError('Nom d’utilisateur déjà utilisé.');
          }
          if (normalizedDisplayName.length < 2) {
            throw StateError('Nom d’affichage invalide.');
          }
          final displayNameTaken = await session.execute(
            Sql.named(
              '''SELECT profile_id FROM profiles
               WHERE LOWER(display_name) = LOWER(@displayName)''',
            ),
            parameters: {'displayName': normalizedDisplayName},
          );
          if (displayNameTaken.isNotEmpty) {
            throw StateError('Nom d’affichage déjà utilisé.');
          }
          final salt = _newSalt();
          await session.execute(
            Sql.named('''INSERT INTO profiles
               (profile_id, username, password_salt, password_hash, display_name)
               VALUES (@id, @username, @salt, @hash, @displayName)'''),
            parameters: {
              'id': profileId,
              'username': normalizedUsername,
              'salt': salt,
              'hash': _hashPassword(password, salt),
              'displayName': normalizedDisplayName,
            },
          );
          final profile = ProfileRecord(
            profileId: profileId,
            displayName: normalizedDisplayName,
            gamesPlayed: 0,
            wins: 0,
            totalScore: 0,
            history: const [],
          );
          return _withSession(profile);
        }

        if (result.isEmpty ||
            result.first[2] == null ||
            result.first[3] == null) {
          throw StateError('Identifiant ou mot de passe incorrect.');
        }
        final row = result.first;
        if (_hashPassword(password, row[2] as String) != row[3]) {
          throw StateError('Identifiant ou mot de passe incorrect.');
        }
        final profile = await _profileFromRow(
          session,
          ResultRow(
            values: [row[0], row[4], row[5], row[6], row[7]],
            schema: result.schema,
          ),
        );
        return _withSession(profile);
      });
    } finally {
      await connection.close();
    }
  }

  ProfileRecord _withSession(ProfileRecord profile) {
    final token = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    _sessions[token] = profile.profileId;
    return profile.copyWith(authToken: token);
  }

  bool isSessionValid(String token, String profileId) =>
      token.isNotEmpty && _sessions[token] == profileId;

  Future<ProfileRecord?> getForSession(String token) async {
    final profileId = _sessions[token];
    if (profileId == null) return null;
    return get(profileId);
  }

  String _newSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(24, (_) => random.nextInt(256)));
  }

  String _hashPassword(String password, String salt) {
    List<int> value = utf8.encode('$salt:$password');
    for (var index = 0; index < 120000; index++) {
      value = sha256.convert(value).bytes;
    }
    return base64UrlEncode(value);
  }

  Future<ProfileRecord> register({
    required String profileId,
    required String displayName,
    required String authToken,
  }) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) throw StateError('Pseudo requis.');
    if (!isSessionValid(authToken, profileId)) {
      throw StateError('Authentification requise.');
    }
    final connection = await _openPostgres();
    try {
      return await connection.runTx((session) async {
        final existing = await session.execute(
          Sql.named(
              '''SELECT profile_id, display_name, games_played, wins, total_score
                 FROM profiles WHERE profile_id = @id'''),
          parameters: {'id': profileId},
        );
        if (existing.isNotEmpty) {
          if (existing.first[1] != normalizedName) {
            throw StateError('Ce profileId est associé à un autre pseudo.');
          }
          return await _profileFromRow(session, existing.first);
        }

        final nameTaken = await session.execute(
          Sql.named(
              'SELECT profile_id FROM profiles WHERE LOWER(display_name) = LOWER(@name)'),
          parameters: {'name': normalizedName},
        );
        if (nameTaken.isNotEmpty) throw StateError('Pseudo déjà utilisé.');

        await session.execute(
          Sql.named(
              'INSERT INTO profiles (profile_id, display_name) VALUES (@id, @name)'),
          parameters: {'id': profileId, 'name': normalizedName},
        );
        return ProfileRecord(
          profileId: profileId,
          displayName: normalizedName,
          gamesPlayed: 0,
          wins: 0,
          totalScore: 0,
          history: const [],
        );
      });
    } finally {
      await connection.close();
    }
  }

  Future<ProfileRecord?> get(String profileId) async {
    final connection = await _openPostgres();
    try {
      final result = await connection.execute(
        Sql.named(
            '''SELECT profile_id, display_name, games_played, wins, total_score
           FROM profiles WHERE profile_id = @id'''),
        parameters: {'id': profileId},
      );
      if (result.isEmpty) return null;
      return await _profileFromRow(connection, result.first);
    } finally {
      await connection.close();
    }
  }

  Future<ProfileRecord> recordGame({
    required String profileId,
    required String opponent,
    required int score,
    required int totalQuestions,
    required bool won,
  }) async {
    final connection = await _openPostgres();
    try {
      return await connection.runTx((session) async {
        final currentResult = await session.execute(
          Sql.named(
              '''SELECT profile_id, display_name, games_played, wins, total_score
             FROM profiles WHERE profile_id = @id FOR UPDATE'''),
          parameters: {'id': profileId},
        );
        if (currentResult.isEmpty) throw StateError('Profil introuvable.');
        await session.execute(
          Sql.named('''INSERT INTO game_history
             (profile_id, score, total_questions, opponent, won)
             VALUES (@id, @score, @total, @opponent, @won)'''),
          parameters: {
            'id': profileId,
            'score': score,
            'total': totalQuestions,
            'opponent': opponent,
            'won': won,
          },
        );
        final updatedResult = await session.execute(
          Sql.named('''UPDATE profiles
             SET games_played = games_played + 1,
                 wins = wins + @win,
                 total_score = total_score + @score,
                 updated_at = NOW()
             WHERE profile_id = @id
             RETURNING profile_id, display_name, games_played, wins, total_score'''),
          parameters: {
            'id': profileId,
            'win': won ? 1 : 0,
            'score': score,
          },
        );
        return _profileFromRow(session, updatedResult.first);
      });
    } finally {
      await connection.close();
    }
  }

  Future<ProfileRecord> _profileFromRow(Session session, ResultRow row) async {
    final historyResult = await session.execute(
      Sql.named('''SELECT played_at, score, total_questions, opponent, won
         FROM game_history
         WHERE profile_id = @id
         ORDER BY played_at DESC, id DESC
         LIMIT 50'''),
      parameters: {'id': row[0]},
    );
    return ProfileRecord(
      profileId: row[0] as String,
      displayName: row[1] as String,
      gamesPlayed: row[2] as int,
      wins: row[3] as int,
      totalScore: row[4] as int,
      history: historyResult
          .map((item) => {
                'playedAt': (item[0] as DateTime).toUtc().toIso8601String(),
                'score': item[1],
                'totalQuestions': item[2],
                'opponent': item[3],
                'won': item[4],
              })
          .toList(),
    );
  }

  Future<Connection> _openPostgres() => Connection.open(
        Endpoint(
          host: postgresHost,
          port: postgresPort,
          database: postgresDatabase,
          username: postgresUsername,
          password: postgresPassword,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );

  Future<void> saveRoomMetadata(String roomId, Map<String, dynamic> metadata) {
    // Demo: metadata survives a Redis restart, but live WebSocket connections
    // cannot be restored. Production would persist answers and reconnections.
    return _redisExecute([
      'SET',
      'quizapp:room:$roomId',
      jsonEncode(metadata),
    ]).then((_) {});
  }

  Future<dynamic> _redisExecute(List<String> command) async {
    final socket = await Socket.connect(redisHost, redisPort)
        .timeout(const Duration(seconds: 3));
    try {
      if (redisPassword != null && redisPassword!.isNotEmpty) {
        await _writeCommand(socket, ['AUTH', redisPassword!]);
        final authResponse = await _RespReader(socket).read();
        if (authResponse != 'OK') {
          throw StateError('Redis authentication failed');
        }
      }
      await _writeCommand(socket, command);
      return await _RespReader(socket).read();
    } finally {
      await socket.close();
    }
  }

  Future<void> _writeCommand(Socket socket, List<String> command) async {
    final buffer = StringBuffer('*${command.length}\r\n');
    for (final item in command) {
      final bytes = utf8.encode(item);
      buffer.write('\$${bytes.length}\r\n$item\r\n');
    }
    socket.add(utf8.encode(buffer.toString()));
    await socket.flush();
  }
}

class _RespReader {
  _RespReader(Socket socket) : _stream = socket;

  final Stream<List<int>> _stream;
  final bytes = <int>[];
  StreamSubscription<List<int>>? subscription;
  Completer<void>? pending;

  Future<int> _readByte() async {
    while (bytes.isEmpty) {
      pending = Completer<void>();
      subscription ??= _stream.listen((chunk) {
        bytes.addAll(chunk);
        if (pending != null && !pending!.isCompleted) pending!.complete();
      }, onDone: () {
        if (pending != null && !pending!.isCompleted) {
          pending!.completeError(StateError('Redis closed connection'));
        }
      });
      await pending!.future;
      pending = null;
    }
    return bytes.removeAt(0);
  }

  Future<List<int>> _readUntilCrlf() async {
    final line = <int>[];
    while (true) {
      final byte = await _readByte();
      if (byte == 13) {
        final next = await _readByte();
        if (next == 10) return line;
        line.add(byte);
        line.add(next);
      } else {
        line.add(byte);
      }
    }
  }

  Future<dynamic> read() async {
    final prefix = await _readByte();
    switch (prefix) {
      case 43:
        return utf8.decode(await _readUntilCrlf());
      case 45:
        throw StateError(utf8.decode(await _readUntilCrlf()));
      case 58:
        return int.parse(utf8.decode(await _readUntilCrlf()));
      case 36:
        final length = int.parse(utf8.decode(await _readUntilCrlf()));
        if (length < 0) return null;
        final value = <int>[];
        for (var index = 0; index < length; index++) {
          value.add(await _readByte());
        }
        await _readByte();
        await _readByte();
        return utf8.decode(value);
      default:
        throw StateError('Unsupported Redis response: $prefix');
    }
  }
}

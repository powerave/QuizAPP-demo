import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final suffix = DateTime.now().microsecondsSinceEpoch.toString();
  final first = await WebSocket.connect('ws://127.0.0.1:8080');
  final second = await WebSocket.connect('ws://127.0.0.1:8080');
  final unknown = await WebSocket.connect('ws://127.0.0.1:8080');
  final firstAuth = await _authenticate('host_$suffix', 'Host_$suffix');
  final secondAuth = await _authenticate('guest_$suffix', 'Guest_$suffix');
  final unknownAuth = await _authenticate('unknown_$suffix', 'Unknown_$suffix');
  final firstMessages = first.asBroadcastStream();
  final secondMessages = second.asBroadcastStream();
  final unknownMessages = unknown.asBroadcastStream();

  first.add(jsonEncode({
    'type': 'create',
    'playerName': 'Host_$suffix',
    'profileId': firstAuth['profileId'],
    'authToken': firstAuth['authToken'],
  }));
  final created = await _next(firstMessages, 'room_created');
  final roomId = created['roomId'] as String;

  second.add(jsonEncode({
    'type': 'list_rooms',
    'profileId': secondAuth['profileId'],
    'authToken': secondAuth['authToken'],
  }));
  final rooms = await _next(secondMessages, 'rooms');
  final visible = (rooms['rooms'] as List).any(
    (room) => (room as Map)['roomId'] == roomId,
  );
  if (!visible) throw StateError('Created room was not listed');

  second.add(jsonEncode({
    'type': 'join',
    'roomId': roomId,
    'playerName': 'Guest_$suffix',
    'profileId': secondAuth['profileId'],
    'authToken': secondAuth['authToken'],
  }));
  await _next(firstMessages, 'question');
  await _next(secondMessages, 'question');

  unknown.add(jsonEncode({
    'type': 'join',
    'roomId': 'MISSING',
    'playerName': 'Unknown_$suffix',
    'profileId': unknownAuth['profileId'],
    'authToken': unknownAuth['authToken'],
  }));
  final error = await _next(unknownMessages, 'error');
  if (error['code'] != 'room_not_found') {
    throw StateError('Unexpected missing room code: ${error['code']}');
  }

  await first.close();
  await second.close();
  await unknown.close();
  stdout.writeln('Room protocol smoke test passed');
}

Future<Map<String, dynamic>> _authenticate(
  String username,
  String displayName,
) async {
  final client = HttpClient();
  try {
    final request =
        await client.postUrl(Uri.parse('http://127.0.0.1:8080/auth'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'username': username,
      'password': 'password123',
      'displayName': displayName,
      'profileId': 'profile-$username',
      'createAccount': true,
    }));
    final response = await request.close();
    final payload = jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Authentication failed: $payload');
    }
    return payload;
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _next(
  Stream<dynamic> messages,
  String expectedType,
) async {
  await for (final raw in messages) {
    final message = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
    if (message['type'] == expectedType) return message;
  }
  throw StateError('WebSocket closed before $expectedType');
}

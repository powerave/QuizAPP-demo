import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class MultiplayerService {
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>> get messages => _channel!.stream.map((message) {
        return Map<String, dynamic>.from(jsonDecode(message as String) as Map);
      });

  Future<void> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
  }

  void join({
    required String roomId,
    required String playerName,
    required String profileId,
    required String authToken,
  }) {
    _send({
      'type': 'join',
      'roomId': roomId,
      'playerName': playerName,
      'profileId': profileId,
      'authToken': authToken,
    });
  }

  void listRooms({required String profileId, required String authToken}) =>
      _send({
        'type': 'list_rooms',
        'profileId': profileId,
        'authToken': authToken,
      });

  void create({
    required String playerName,
    required String profileId,
    required String authToken,
  }) {
    _send({
      'type': 'create',
      'playerName': playerName,
      'profileId': profileId,
      'authToken': authToken,
    });
  }

  void answer(int optionIndex) {
    _send({'type': 'answer', 'optionIndex': optionIndex});
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> dispose() async {
    await _channel?.sink.close();
    _channel = null;
  }
}

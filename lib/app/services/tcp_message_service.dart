import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/speech_message.dart';

class TcpMessageService {
  static const int applicationPort = 7070;
  ServerSocket? _serverSocket;
  final List<Socket> _serverClients = <Socket>[];
  Socket? _clientSocket;
  final Map<Socket, String> _pendingBySocket = <Socket, String>{};

  FutureOr<void> Function(SpeechMessage message)? onMessage;
  void Function(String status)? onStatus;

  bool get isConnected {
    return _clientSocket != null || _serverClients.isNotEmpty;
  }

  Future<void> startServer({required int port}) async {
    await close();

    const int actualPort = applicationPort;

    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      actualPort,
      shared: true,
    );

    onStatus?.call(
      'SERVER LISTENING: 0.0.0.0:$actualPort',
    );

    _serverSocket!.listen(
      (Socket socket) {
        _serverClients.add(socket);

        onStatus?.call(
          'Client connected from ${socket.remoteAddress.address}',
        );

        _attachSocket(
          socket,
          removeFromServerList: true,
          clearClientOnDone: false,
        );
      },
      onError: (Object error) {
        onStatus?.call('Server error: $error');
      },
    );
  }

  Future<void> connect({
    required String host,
    required int port,
  }) async {
    await close();

    const int actualPort = applicationPort;

    onStatus?.call(
      'CONNECTING TO $host:$actualPort',
    );

    _clientSocket = await Socket.connect(
      host,
      actualPort,
      timeout: const Duration(seconds: 5),
    );

    onStatus?.call(
      'CONNECTED TO $host:$actualPort',
    );

    _attachSocket(
      _clientSocket!,
      removeFromServerList: false,
      clearClientOnDone: true,
    );
  }

  Future<void> send(SpeechMessage message) async {
    final String payload = '${jsonEncode(message.toJsonNetwork())}\n';
    bool delivered = false;

    if (_clientSocket != null) {
      _clientSocket!.write(payload);
      delivered = true;
    }

    for (final Socket client in _serverClients) {
      client.write(payload);
      delivered = true;
    }

    if (!delivered) {
      throw StateError('No TCP peer connected to send the message.');
    }
  }

  void _attachSocket(
    Socket socket, {
    required bool removeFromServerList,
    required bool clearClientOnDone,
  }) {
    _pendingBySocket[socket] = '';

    socket.listen(
      (List<int> bytes) => _handleChunk(socket, bytes),
      onDone: () {
        _pendingBySocket.remove(socket);
        if (removeFromServerList) {
          _serverClients.remove(socket);
        }
        if (clearClientOnDone && identical(_clientSocket, socket)) {
          _clientSocket = null;
        }
        onStatus?.call('Socket disconnected.');
      },
      onError: (Object error) {
        onStatus?.call('Socket error: $error');
      },
      cancelOnError: true,
    );
  }

  void _handleChunk(Socket socket, List<int> bytes) {
    final String previous = _pendingBySocket[socket] ?? '';
    final String merged = '$previous${utf8.decode(bytes)}';
    final List<String> lines = merged.split('\n');
    _pendingBySocket[socket] = lines.removeLast();

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      _decodeMessage(trimmed);
    }
  }

  void _decodeMessage(String rawJson) {
    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        onStatus?.call('Dropped malformed packet.');
        return;
      }
      final FutureOr<void>? result = onMessage?.call(
        SpeechMessage.fromJson(decoded),
      );
      if (result is Future<void>) {
        unawaited(result);
      }
    } catch (error) {
      onStatus?.call('JSON decode error: $error');
    }
  }

  Future<void> close() async {
    for (final Socket client in _serverClients.toList()) {
      await client.close();
    }
    _serverClients.clear();

    if (_clientSocket != null) {
      await _clientSocket!.close();
      _clientSocket = null;
    }

    if (_serverSocket != null) {
      await _serverSocket!.close();
      _serverSocket = null;
    }

    _pendingBySocket.clear();
  }
}

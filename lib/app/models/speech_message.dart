enum MessageType { speech, emergency, system }

enum MessageOrigin { local, remote, system }

MessageType messageTypeFromWire(String rawType) {
  switch (rawType) {
    case 'speech':
      return MessageType.speech;
    case 'emergency':
      return MessageType.emergency;
    default:
      return MessageType.system;
  }
}

String messageTypeToWire(MessageType type) {
  switch (type) {
    case MessageType.speech:
      return 'speech';
    case MessageType.emergency:
      return 'emergency';
    case MessageType.system:
      return 'system';
  }
}

class SpeechMessage {
  const SpeechMessage({
    required this.id,
    required this.type,
    required this.languageCode,
    required this.message,
    required this.timestamp,
    required this.origin,
  });

  final String id;
  final MessageType type;
  final String languageCode;
  final String message;
  final DateTime timestamp;
  final MessageOrigin origin;

  factory SpeechMessage.fromJson(
    Map<String, dynamic> json, {
    MessageOrigin origin = MessageOrigin.remote,
  }) {
    final Object? timestampRaw = json['timestamp'] ?? json['timestampEpochMs'];
    final int timestampMs = switch (timestampRaw) {
      int value => value,
      String value =>
        int.tryParse(value) ?? DateTime.now().millisecondsSinceEpoch,
      _ => DateTime.now().millisecondsSinceEpoch,
    };

    return SpeechMessage(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      type: messageTypeFromWire((json['type'] ?? 'speech').toString()),
      languageCode: (json['language'] ?? 'en').toString(),
      message: (json['message'] ?? '').toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      origin: origin,
    );
  }

  Map<String, dynamic> toJsonNetwork() {
    return <String, dynamic>{
      'id': id,
      'type': messageTypeToWire(type),
      'language': languageCode,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  SpeechMessage copyWith({
    MessageType? type,
    String? languageCode,
    String? message,
    DateTime? timestamp,
    MessageOrigin? origin,
  }) {
    return SpeechMessage(
      id: id,
      type: type ?? this.type,
      languageCode: languageCode ?? this.languageCode,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      origin: origin ?? this.origin,
    );
  }
}

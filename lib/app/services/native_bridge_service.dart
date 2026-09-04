import 'dart:async';

import 'package:flutter/services.dart';

import '../models/operation_mode.dart';

enum NativeEventType {
  partial,
  finalSentence,
  ttsStarted,
  audioStarted,
  resourceMetrics,
  status,
  error,
}

NativeEventType nativeEventTypeFromWire(String rawType) {
  switch (rawType) {
    case 'partial':
      return NativeEventType.partial;
    case 'final_sentence':
      return NativeEventType.finalSentence;
    case 'tts_started':
      return NativeEventType.ttsStarted;
    case 'audio_started':
      return NativeEventType.audioStarted;
    case 'resource_metrics':
      return NativeEventType.resourceMetrics;
    case 'error':
      return NativeEventType.error;
    default:
      return NativeEventType.status;
  }
}

class NativeEvent {
  NativeEvent({
    required this.type,
    this.text,
    this.messageId,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final NativeEventType type;
  final String? text;
  final String? messageId;
  final Map<dynamic, dynamic>? payload;
  final DateTime timestamp;

  factory NativeEvent.fromMap(Map<dynamic, dynamic> raw) {
    final String rawType = (raw['type'] ?? 'status').toString();
    return NativeEvent(
      type: nativeEventTypeFromWire(rawType),
      text: raw['text']?.toString(),
      messageId: raw['messageId']?.toString(),
      payload: raw,
      timestamp: DateTime.now(),
    );
  }
}

class NativeBridgeService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.sih.voicebridge/native',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.sih.voicebridge/native_events',
  );

  final StreamController<NativeEvent> _eventsController =
      StreamController<NativeEvent>.broadcast();

  StreamSubscription<dynamic>? _nativeEventSubscription;
  bool _nativeAvailable = true;
  String? _activeMessageId;

  Stream<NativeEvent> get events => _eventsController.stream;
  bool get nativeAvailable => _nativeAvailable;

  Future<void> initialize({required String languageCode}) async {
    await _subscribeToEventStream();
    await _invoke('initializePipelines', <String, dynamic>{
      'languageCode': languageCode,
    });
  }

  Future<void> setLanguage(String languageCode) async {
    await _invoke('setLanguage', <String, dynamic>{
      'languageCode': languageCode,
    });
  }

  Future<void> setOperationMode(OperationMode mode) async {
    await _invoke('setOperationMode', <String, dynamic>{
      'mode': operationModeToWire(mode),
    });
  }

  Future<void> startListening({
    required bool ptt,
    required String languageCode,
    required String messageId,
  }) async {
    _activeMessageId = messageId;
    final bool ok = await _invoke('startListening', <String, dynamic>{
      'ptt': ptt,
      'languageCode': languageCode,
      'messageId': messageId,
    });
    if (!ok) {
      _eventsController.add(
        NativeEvent(
          type: NativeEventType.status,
          text: 'Native pipeline unavailable. Running in scaffold mode.',
        ),
      );
    }
  }

  Future<void> stopListening() async {
    final bool ok = await _invoke('stopListening');
    if (!ok) {
      final String messageId =
          _activeMessageId ?? 'mock-${DateTime.now().microsecondsSinceEpoch}';
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _eventsController.add(
        NativeEvent(
          type: NativeEventType.finalSentence,
          text: 'Emergency assistance is required',
          messageId: messageId,
        ),
      );
    }
  }

  Future<void> speakText({
    required String text,
    required bool emergency,
    required String languageCode,
    required String messageId,
  }) async {
    final bool ok = await _invoke('speakText', <String, dynamic>{
      'text': text,
      'emergency': emergency,
      'languageCode': languageCode,
      'messageId': messageId,
    });
    if (!ok) {
      _eventsController.add(
        NativeEvent(
          type: NativeEventType.ttsStarted,
          text: text,
          messageId: messageId,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _eventsController.add(
        NativeEvent(
          type: NativeEventType.audioStarted,
          text: text,
          messageId: messageId,
        ),
      );
    }
  }

  Future<void> setEmergencyOverride(bool enabled) async {
    await _invoke('setEmergencyOverride', <String, dynamic>{
      'enabled': enabled,
    });
  }

  Future<String?> getAppDataDirectoryPath() async {
    try {
      final String? path = await _methodChannel.invokeMethod<String>(
        'getAppDataDirectory',
      );
      if (path == null || path.trim().isEmpty) {
        return null;
      }
      return path.trim();
    } on MissingPluginException {
      _nativeAvailable = false;
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, args);
      return true;
    } on MissingPluginException {
      _nativeAvailable = false;
      return false;
    } on PlatformException catch (error) {
      _eventsController.add(
        NativeEvent(
          type: NativeEventType.error,
          text: error.message ?? error.code,
          messageId: _activeMessageId,
        ),
      );
      return false;
    }
  }

  Future<void> _subscribeToEventStream() async {
    if (_nativeEventSubscription != null) {
      return;
    }

    try {
      _nativeEventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic payload) {
          if (payload is Map<dynamic, dynamic>) {
            _eventsController.add(NativeEvent.fromMap(payload));
          }
        },
        onError: (Object error) {
          _eventsController.add(
            NativeEvent(
              type: NativeEventType.error,
              text: error.toString(),
              messageId: _activeMessageId,
            ),
          );
        },
      );
    } on MissingPluginException {
      _nativeAvailable = false;
    }
  }

  Future<void> dispose() async {
    await _nativeEventSubscription?.cancel();
    await _eventsController.close();
  }
}

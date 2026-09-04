import 'dart:convert';
import 'dart:io';

import '../models/benchmark_models.dart';
import '../models/speech_message.dart';

class PersistedBenchmarkHistory {
  const PersistedBenchmarkHistory({
    required this.snapshots,
    required this.messagesById,
  });

  final List<BenchmarkSnapshot> snapshots;
  final Map<String, SpeechMessage> messagesById;
}

class BenchmarkHistoryStorageService {
  static const String _fileName = 'benchmark_history_v1.json';

  Future<PersistedBenchmarkHistory> load({
    required Future<String?> Function() appDataPathProvider,
  }) async {
    final File file = await _resolveFile(appDataPathProvider);
    if (!await file.exists()) {
      return _empty();
    }

    try {
      final String rawJson = await file.readAsString();
      if (rawJson.trim().isEmpty) {
        return _empty();
      }

      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return _empty();
      }

      final Object? samplesRaw = decoded['samples'];
      if (samplesRaw is! List) {
        return _empty();
      }

      final List<BenchmarkSnapshot> snapshots = <BenchmarkSnapshot>[];
      final Map<String, SpeechMessage> messagesById = <String, SpeechMessage>{};

      for (final Object? item in samplesRaw) {
        if (item is! Map) {
          continue;
        }

        final Map<dynamic, dynamic> sample = item;
        final BenchmarkSnapshot? snapshot = _snapshotFromMap(sample);
        if (snapshot == null) {
          continue;
        }

        snapshots.add(snapshot);
        final SpeechMessage? message =
            _messageFromMap(sample['message'], fallbackId: snapshot.messageId);
        if (message != null) {
          messagesById[snapshot.messageId] = message;
        }
      }

      return PersistedBenchmarkHistory(
        snapshots: snapshots,
        messagesById: messagesById,
      );
    } catch (_) {
      return _empty();
    }
  }

  Future<void> save({
    required List<BenchmarkSnapshot> snapshots,
    required SpeechMessage? Function(String messageId) messageLookup,
    required Future<String?> Function() appDataPathProvider,
  }) async {
    final File file = await _resolveFile(appDataPathProvider);
    final Map<String, dynamic> payload = <String, dynamic>{
      'samples': snapshots
          .map(
            (BenchmarkSnapshot snapshot) =>
                _snapshotToMap(snapshot, messageLookup(snapshot.messageId)),
          )
          .toList(growable: false),
    };

    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<void> clear({
    required Future<String?> Function() appDataPathProvider,
  }) async {
    final File file = await _resolveFile(appDataPathProvider);
    if (await file.exists()) {
      await file.delete();
    }
  }

  PersistedBenchmarkHistory _empty() {
    return const PersistedBenchmarkHistory(
      snapshots: <BenchmarkSnapshot>[],
      messagesById: <String, SpeechMessage>{},
    );
  }

  Future<File> _resolveFile(
    Future<String?> Function() appDataPathProvider,
  ) async {
    String? directoryPath;
    try {
      directoryPath = await appDataPathProvider();
    } catch (_) {
      directoryPath = null;
    }

    final String basePath;
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      basePath = Directory.systemTemp.path;
    } else {
      basePath = directoryPath.trim();
    }

    return File('$basePath${Platform.pathSeparator}$_fileName');
  }

  Map<String, dynamic> _snapshotToMap(
    BenchmarkSnapshot snapshot,
    SpeechMessage? message,
  ) {
    final Map<String, dynamic> map = <String, dynamic>{
      'messageId': snapshot.messageId,
      'marks': <String, String?>{
        't0SpeechStart': _iso(snapshot.marks.t0SpeechStart),
        't1SpeechEnd': _iso(snapshot.marks.t1SpeechEnd),
        't2SttFinal': _iso(snapshot.marks.t2SttFinal),
        't3MessageSent': _iso(snapshot.marks.t3MessageSent),
        't4MessageReceived': _iso(snapshot.marks.t4MessageReceived),
        't5TtsStart': _iso(snapshot.marks.t5TtsStart),
        't6AudioFirstFrame': _iso(snapshot.marks.t6AudioFirstFrame),
      },
      'audioDurationMs': snapshot.audioDuration?.inMilliseconds,
      'processingDurationMs': snapshot.processingDuration?.inMilliseconds,
      'resource': <String, double?>{
        'sttRamMb': snapshot.resource.sttRamMb,
        'ttsRamMb': snapshot.resource.ttsRamMb,
        'idleRamMb': snapshot.resource.idleRamMb,
        'peakRamMb': snapshot.resource.peakRamMb,
        'idleCpuPct': snapshot.resource.idleCpuPct,
        'sttCpuPct': snapshot.resource.sttCpuPct,
        'ttsCpuPct': snapshot.resource.ttsCpuPct,
        'sttModelSizeMb': snapshot.resource.sttModelSizeMb,
        'ttsModelSizeMb': snapshot.resource.ttsModelSizeMb,
        'apkSizeMb': snapshot.resource.apkSizeMb,
      },
    };

    if (message != null) {
      map['message'] = <String, dynamic>{
        'id': message.id,
        'type': messageTypeToWire(message.type),
        'language': message.languageCode,
        'text': message.message,
        'timestampMs': message.timestamp.millisecondsSinceEpoch,
        'origin': _originToWire(message.origin),
      };
    }

    return map;
  }

  BenchmarkSnapshot? _snapshotFromMap(Map<dynamic, dynamic> map) {
    final String messageId = (map['messageId'] ?? '').toString();
    if (messageId.isEmpty) {
      return null;
    }

    final Map<dynamic, dynamic> marksMap =
        map['marks'] is Map ? map['marks'] as Map<dynamic, dynamic> : const {};
    final BenchmarkMarks marks = BenchmarkMarks()
      ..t0SpeechStart = _parseIso(marksMap['t0SpeechStart'])
      ..t1SpeechEnd = _parseIso(marksMap['t1SpeechEnd'])
      ..t2SttFinal = _parseIso(marksMap['t2SttFinal'])
      ..t3MessageSent = _parseIso(marksMap['t3MessageSent'])
      ..t4MessageReceived = _parseIso(marksMap['t4MessageReceived'])
      ..t5TtsStart = _parseIso(marksMap['t5TtsStart'])
      ..t6AudioFirstFrame = _parseIso(marksMap['t6AudioFirstFrame']);

    final Map<dynamic, dynamic> resourceMap = map['resource'] is Map
        ? map['resource'] as Map<dynamic, dynamic>
        : const {};
    final ResourceBenchmark resource = ResourceBenchmark(
      sttRamMb: _parseDouble(resourceMap['sttRamMb']),
      ttsRamMb: _parseDouble(resourceMap['ttsRamMb']),
      idleRamMb: _parseDouble(resourceMap['idleRamMb']),
      peakRamMb: _parseDouble(resourceMap['peakRamMb']),
      idleCpuPct: _parseDouble(resourceMap['idleCpuPct']),
      sttCpuPct: _parseDouble(resourceMap['sttCpuPct']),
      ttsCpuPct: _parseDouble(resourceMap['ttsCpuPct']),
      sttModelSizeMb: _parseDouble(resourceMap['sttModelSizeMb']),
      ttsModelSizeMb: _parseDouble(resourceMap['ttsModelSizeMb']),
      apkSizeMb: _parseDouble(resourceMap['apkSizeMb']),
    );

    return BenchmarkSnapshot(
      messageId: messageId,
      marks: marks,
      resource: resource,
      audioDuration: _parseDuration(map['audioDurationMs']),
      processingDuration: _parseDuration(map['processingDurationMs']),
    );
  }

  SpeechMessage? _messageFromMap(Object? raw, {required String fallbackId}) {
    if (raw is! Map) {
      return null;
    }

    final String message = (raw['text'] ?? '').toString();
    if (message.trim().isEmpty) {
      return null;
    }

    final int timestampMs =
        _parseInt(raw['timestampMs']) ?? DateTime.now().millisecondsSinceEpoch;

    return SpeechMessage(
      id: (raw['id'] ?? fallbackId).toString(),
      type: messageTypeFromWire((raw['type'] ?? 'speech').toString()),
      languageCode: (raw['language'] ?? 'en').toString(),
      message: message,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      origin: _originFromWire((raw['origin'] ?? 'remote').toString()),
    );
  }

  String? _iso(DateTime? value) {
    return value?.toIso8601String();
  }

  DateTime? _parseIso(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Duration? _parseDuration(Object? value) {
    final int? milliseconds = _parseInt(value);
    if (milliseconds == null || milliseconds < 0) {
      return null;
    }
    return Duration(milliseconds: milliseconds);
  }

  int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  MessageOrigin _originFromWire(String raw) {
    switch (raw) {
      case 'local':
        return MessageOrigin.local;
      case 'system':
        return MessageOrigin.system;
      default:
        return MessageOrigin.remote;
    }
  }

  String _originToWire(MessageOrigin origin) {
    switch (origin) {
      case MessageOrigin.local:
        return 'local';
      case MessageOrigin.remote:
        return 'remote';
      case MessageOrigin.system:
        return 'system';
    }
  }
}

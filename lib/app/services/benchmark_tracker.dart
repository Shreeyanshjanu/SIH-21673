import '../models/benchmark_models.dart';

class BenchmarkTracker {
  final Map<String, BenchmarkMarks> _marksByMessageId =
      <String, BenchmarkMarks>{};
  ResourceBenchmark _resourceBenchmark = const ResourceBenchmark(
    sttModelSizeMb: 175,
  );

  ResourceBenchmark get resourceBenchmark => _resourceBenchmark;

  void mark(String messageId, BenchmarkEvent event, {DateTime? at}) {
    final BenchmarkMarks marks = _marksByMessageId.putIfAbsent(
      messageId,
      BenchmarkMarks.new,
    );
    marks.set(event, at ?? DateTime.now());
  }

  void updateResourceUsage(ResourceBenchmark usage) {
    _resourceBenchmark = usage;
  }

  BenchmarkSnapshot snapshotFor(
    String messageId, {
    Duration? audioDuration,
    Duration? processingDuration,
  }) {
    final BenchmarkMarks marks =
        (_marksByMessageId[messageId] ?? BenchmarkMarks()).clone();

    return BenchmarkSnapshot(
      messageId: messageId,
      marks: marks,
      resource: _resourceBenchmark,
      audioDuration: audioDuration,
      processingDuration: processingDuration ?? _inferProcessingDuration(marks),
    );
  }

  void clear(String messageId) {
    _marksByMessageId.remove(messageId);
  }

  Duration? _inferProcessingDuration(BenchmarkMarks marks) {
    final DateTime? start = marks.t0SpeechStart;
    final DateTime? end = marks.t6AudioFirstFrame ?? marks.t2SttFinal;
    if (start == null || end == null || end.isBefore(start)) {
      return null;
    }
    return end.difference(start);
  }
}

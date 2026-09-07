import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/benchmark_models.dart';
import '../models/connection_config.dart';
import '../models/language_option.dart';
import '../models/operation_mode.dart';
import '../models/speech_message.dart';
import '../state/app_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  final TextEditingController _composeController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final ConnectionConfig config = widget.controller.connectionConfig;

    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());

    unawaited(widget.controller.initialize());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final AppController controller = widget.controller;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SIH Offline Voice Bridge'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Clear history',
                onPressed: controller.clearHistory,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  _buildStatusBanner(controller.status),
                  const SizedBox(height: 8),
                  _buildConnectionCard(controller),
                  const SizedBox(height: 8),
                  _buildLanguageCard(controller),
                  const SizedBox(height: 8),
                  _buildModeCard(controller),
                  const SizedBox(height: 8),
                  _buildControlsCard(controller),
                  const SizedBox(height: 8),
                  _buildBenchmarkCard(controller),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 250,
                    child: _buildHistoryList(controller.history),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(String status) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(status),
      ),
    );
  }

  Widget _buildConnectionCard(AppController controller) {
    final ConnectionConfig config = controller.connectionConfig;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Connection Management (Local Wi-Fi / TCP)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Run as server'),
              value: config.runAsServer,
              onChanged: (bool value) {
                controller.updateConnectionConfig(
                  config.copyWith(runAsServer: value),
                );
              },
            ),
            TextField(
              controller: _hostController,
              enabled: !config.runAsServer,
              decoration: const InputDecoration(
                labelText: 'Peer host/IP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Port',
                helperText: 'Fixed application port: 7070',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      _applyConnectionInput(controller);

                      if (controller.isConnected) {
                        await controller.disconnect();
                      } else {
                        await controller.connect();
                      }
                    },
                    child: Text(
                      controller.isConnected ? 'Disconnect' : 'Connect',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(AppController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Language Selection',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<LanguageOption>(
              initialValue: controller.selectedLanguage,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: kLanguageOptions.map((LanguageOption language) {
                final String subtitle = language.status;

                return DropdownMenuItem<LanguageOption>(
                  value: language,
                  child: Text(
                    '${language.label} - $subtitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (LanguageOption? value) {
                if (value == null) {
                  return;
                }

                unawaited(controller.setLanguage(value));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(AppController controller) {
    final bool walkieTalkie =
        controller.operationMode == OperationMode.walkieTalkie;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Conversation Mode',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ToggleButtons(
                isSelected: <bool>[
                  walkieTalkie,
                  !walkieTalkie,
                ],
                onPressed: (int index) {
                  final OperationMode mode = index == 0
                      ? OperationMode.walkieTalkie
                      : OperationMode.continuous;

                  unawaited(controller.setOperationMode(mode));
                },
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Walkie-talkie'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Continuous'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(AppController controller) {
    final bool isWalkieTalkie =
        controller.operationMode == OperationMode.walkieTalkie;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'PTT / Message Controls',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (isWalkieTalkie)
              _buildHoldToTalkButton(controller)
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: controller.isListening
                          ? null
                          : () => unawaited(
                                controller.startPushToTalk(),
                              ),
                      child: const Text('Start Listening'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.isListening
                          ? () => unawaited(
                                controller.stopPushToTalk(),
                              )
                          : null,
                      child: const Text('Stop & Finalize'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _composeController,
              decoration: const InputDecoration(
                labelText: 'Manual text message',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final String text = _composeController.text;

                      _composeController.clear();

                      await controller.sendTypedMessage(text);
                    },
                    child: const Text('Send Speech Message'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      final String typed = _composeController.text.trim();

                      _composeController.clear();

                      if (typed.isNotEmpty) {
                        await controller.sendTypedMessage(
                          typed,
                          emergency: true,
                        );
                      } else {
                        await controller.sendEmergencyPreset();
                      }
                    },
                    child: const Text('Emergency Alert'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Partial transcript: '
              '${controller.partialTranscript.isEmpty ? '-' : controller.partialTranscript}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldToTalkButton(AppController controller) {
    final bool active = controller.isListening;
    final Color color = active ? Colors.red : Colors.green;

    return Listener(
      onPointerDown: (_) => unawaited(
        controller.startPushToTalk(),
      ),
      onPointerUp: (_) => unawaited(
        controller.stopPushToTalk(),
      ),
      onPointerCancel: (_) => unawaited(
        controller.stopPushToTalk(),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(
            color: color,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.mic,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              active ? 'RELEASE TO SEND' : 'HOLD TO TALK',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkCard(AppController controller) {
    final BenchmarkSnapshot? snapshot = controller.latestBenchmark;

    final ResourceBenchmark resource = controller.resourceBenchmark;

    final bool canExport = snapshot != null;
    final bool hasHistory = controller.benchmarkHistory.isNotEmpty;

    final int historyCount = controller.benchmarkHistory.length;

    String ms(Duration? value) {
      return value == null ? '-' : '${value.inMilliseconds} ms';
    }

    String mb(double? value) {
      return value == null ? '-' : '${value.toStringAsFixed(2)} MB';
    }

    String pct(double? value) {
      return value == null ? '-' : '${value.toStringAsFixed(2)}%';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Benchmarking (T0..T6)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'STT latency: ${ms(snapshot?.sttLatency)}',
            ),
            Text(
              'Network latency: ${ms(snapshot?.networkLatency)}',
            ),
            Text(
              'TTS latency: ${ms(snapshot?.ttsLatency)}',
            ),
            Text(
              'End-to-end: ${ms(snapshot?.endToEndLatency)}',
            ),
            Text(
              'RTF: ${snapshot?.rtf == null ? '-' : snapshot!.rtf!.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Idle RAM: ${mb(resource.idleRamMb)}',
            ),
            Text(
              'STT RAM: ${mb(resource.sttRamMb)}',
            ),
            Text(
              'TTS RAM: ${mb(resource.ttsRamMb)}',
            ),
            Text(
              'Peak RAM: ${mb(resource.peakRamMb)}',
            ),
            Text(
              'Idle CPU: ${pct(resource.idleCpuPct)}',
            ),
            Text(
              'STT CPU: ${pct(resource.sttCpuPct)}',
            ),
            Text(
              'TTS CPU: ${pct(resource.ttsCpuPct)}',
            ),
            Text(
              'STT model size: ${mb(resource.sttModelSizeMb)}',
            ),
            Text(
              'TTS model size: ${mb(resource.ttsModelSizeMb)}',
            ),
            Text(
              'APK size: ${mb(resource.apkSizeMb)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Stored samples: $historyCount / 50',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: canExport
                      ? () => unawaited(
                            _copyBenchmark(
                              controller.exportLatestBenchmarkAsJson(),
                              successMessage: 'Benchmark JSON copied',
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.data_object),
                  label: const Text('Copy JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: canExport
                      ? () => unawaited(
                            _copyBenchmark(
                              controller.exportLatestBenchmarkAsCsv(),
                              successMessage: 'Benchmark CSV copied',
                            ),
                          )
                      : null,
                  icon: const Icon(
                    Icons.table_chart_outlined,
                  ),
                  label: const Text('Copy CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: hasHistory
                      ? () => unawaited(
                            _copyBenchmark(
                              controller.exportBenchmarkHistoryAsJson(),
                              successMessage: 'Benchmark history JSON copied',
                            ),
                          )
                      : null,
                  icon: const Icon(
                    Icons.dataset_outlined,
                  ),
                  label: const Text('History JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: hasHistory
                      ? () => unawaited(
                            _copyBenchmark(
                              controller.exportBenchmarkHistoryAsCsv(),
                              successMessage: 'Benchmark history CSV copied',
                            ),
                          )
                      : null,
                  icon: const Icon(
                    Icons.view_list_outlined,
                  ),
                  label: const Text('History CSV'),
                ),
              ],
            ),
            if (!canExport)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Run one message to enable export.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyBenchmark(
    String? payload, {
    required String successMessage,
  }) async {
    if (payload == null || payload.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No benchmark snapshot to export yet.',
            ),
          ),
        );

      return;
    }

    await Clipboard.setData(
      ClipboardData(text: payload),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(successMessage),
        ),
      );
  }

  Widget _buildHistoryList(
    List<SpeechMessage> history,
  ) {
    return Card(
      child: history.isEmpty
          ? const Center(
              child: Text('No messages yet.'),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final SpeechMessage message = history[index];

                return ListTile(
                  leading: Icon(
                    _iconFor(message),
                  ),
                  title: Text(
                    message.message,
                  ),
                  subtitle: Text(
                    '${message.languageCode.toUpperCase()} • '
                    '${message.timestamp.toLocal()}',
                  ),
                  trailing: Text(
                    messageTypeToWire(message.type),
                  ),
                );
              },
            ),
    );
  }

  IconData _iconFor(SpeechMessage message) {
    if (message.type == MessageType.emergency) {
      return Icons.warning_rounded;
    }

    if (message.origin == MessageOrigin.local) {
      return Icons.north_east;
    }

    return Icons.south_west;
  }

  void _applyConnectionInput(AppController controller) {
    controller.updateConnectionConfig(
      controller.connectionConfig.copyWith(
        host: _hostController.text.trim(),
        port: ConnectionConfig.networkPort,
      ),
    );

    _portController.text = ConnectionConfig.networkPort.toString();
  }
}

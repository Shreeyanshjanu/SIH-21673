class ConnectionConfig {
  const ConnectionConfig({
    required this.host,
    required this.port,
    required this.runAsServer,
  });

  static const int networkPort = 7070;

  final String host;
  final int port;
  final bool runAsServer;

  ConnectionConfig copyWith({
    String? host,
    int? port,
    bool? runAsServer,
  }) {
    return ConnectionConfig(
      host: host ?? this.host,
      port: networkPort,
      runAsServer: runAsServer ?? this.runAsServer,
    );
  }

  static const ConnectionConfig initial = ConnectionConfig(
    host: '',
    port: networkPort,
    runAsServer: true,
  );
}
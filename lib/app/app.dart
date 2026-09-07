import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';

class SihVoiceBridgeApp extends StatefulWidget {
  const SihVoiceBridgeApp({super.key});

  @override
  State<SihVoiceBridgeApp> createState() => _SihVoiceBridgeAppState();
}

class _SihVoiceBridgeAppState extends State<SihVoiceBridgeApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iTantra Voice Bridge',
      theme: AppTheme.dark(),
      home: AppShell(controller: _controller),
    );
  }
}

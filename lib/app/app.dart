import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'ui/home_screen.dart';

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
      title: 'SIH Voice Bridge',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: HomeScreen(controller: _controller),
    );
  }
}

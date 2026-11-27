import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/lcars_console_screen.dart';
import 'services/lcars_controller.dart';
import 'theme/lcars_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LcarsLauncherApp());
}

class LcarsLauncherApp extends StatefulWidget {
  const LcarsLauncherApp({super.key});

  @override
  State<LcarsLauncherApp> createState() => _LcarsLauncherAppState();
}

class _LcarsLauncherAppState extends State<LcarsLauncherApp> {
  late final LcarsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LcarsController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LCARS Launcher',
      debugShowCheckedModeBanner: false,
      theme: buildLcarsTheme(),
      home: LcarsConsoleScreen(controller: _controller),
    );
  }
}

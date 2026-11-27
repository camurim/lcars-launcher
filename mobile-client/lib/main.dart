import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/lcars_console_screen.dart';
import 'services/lcars_controller.dart';
import 'theme/lcars_theme.dart';

void _enableImmersiveFullscreen() {
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _enableImmersiveFullscreen();
  runApp(const LcarsLauncherApp());
}

class LcarsLauncherApp extends StatefulWidget {
  const LcarsLauncherApp({super.key});

  @override
  State<LcarsLauncherApp> createState() => _LcarsLauncherAppState();
}

class _LcarsLauncherAppState extends State<LcarsLauncherApp>
    with WidgetsBindingObserver {
  late final LcarsController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableImmersiveFullscreen();
    _controller = LcarsController();
    unawaited(_controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableImmersiveFullscreen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) =>
          AppLocalizations.of(ctx)?.appTitle ?? 'LCARS Launcher',
      debugShowCheckedModeBanner: false,
      theme: buildLcarsTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('pt'),
        Locale('es'),
      ],
      home: LcarsConsoleScreen(controller: _controller),
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'config/api_config.dart';
import 'screens/home_screen.dart';
import 'services/reader_connection_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initSqliteForDesktop();
  // 画面遷移後も切断イベントを処理（自動接続はしない）
  ReaderConnectionSession.instance.ensureStarted();
  runApp(const TagReaderApp());
}

/// Windows / Linux / macOS では sqflite_common_ffi を使う。
void _initSqliteForDesktop() {
  if (kIsWeb) return;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

class TagReaderApp extends StatelessWidget {
  const TagReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kAppEnvValidation.isValid) {
      return MaterialApp(
        title: 'タグリーダー',
        home: _EnvErrorScreen(message: kAppEnvValidation.errorMessage!),
      );
    }

    return MaterialApp(
      title: 'タグリーダー',
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) {
        if (!kIsStagingFlavor) return child ?? const SizedBox.shrink();
        return Column(
          children: [
            Material(
              color: const Color(0xFFE65100),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'テスト環境',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const HomeScreen(),
    );
  }
}

class _EnvErrorScreen extends StatelessWidget {
  const _EnvErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

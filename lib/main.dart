import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/api_config.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TagReaderApp());
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

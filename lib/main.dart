import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const TagReaderApp());
}

class TagReaderApp extends StatelessWidget {
  const TagReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'タグリーダー',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

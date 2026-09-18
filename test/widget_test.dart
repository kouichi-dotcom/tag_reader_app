import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tag_reader_app/main.dart';

void main() {
  testWidgets('TagReaderApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const TagReaderApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

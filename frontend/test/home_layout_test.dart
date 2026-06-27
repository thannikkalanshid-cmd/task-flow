import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen lays out without render exceptions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
        home: const HomeScreen(token: 'layout-test-token'),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

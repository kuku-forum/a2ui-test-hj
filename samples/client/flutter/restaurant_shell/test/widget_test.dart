// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_shell/main.dart';

void main() {
  testWidgets('Restaurant Shell app shows title and input', (WidgetTester tester) async {
    await tester.pumpWidget(const RestaurantShellApp());

    expect(find.text('Restaurant Finder'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });
}

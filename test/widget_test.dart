import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterfashion_app/main.dart';

void main() {
  testWidgets('App starts with splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that splash screen is displayed
    expect(find.byType(SplashScreen), findsOneWidget);
    
    // Verify loading text is present
    expect(find.text('Loading Fashion App...'), findsOneWidget);
  });

  testWidgets('MyApp widget test', (WidgetTester tester) async {
    // Build MyApp widget
    await tester.pumpWidget(const MyApp());

    // Verify that MaterialApp is created
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('SplashScreen contains expected elements', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // Verify main elements exist
    expect(find.text('Loading Fashion App...'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
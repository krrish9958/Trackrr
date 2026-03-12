import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_tracking_app/src/features/auth/presentation/pages/login_page.dart';
import 'package:parcel_tracking_app/src/theme/app_theme.dart';

void main() {
  testWidgets('renders login form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginPage(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Trackrr'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}

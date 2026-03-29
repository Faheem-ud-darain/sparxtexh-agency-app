// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:company_app/main.dart';

void main() {
  testWidgets('Agency Hub Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: This will fail in real CI without Firebase initialized,
    // but for static analysis we keep it simple.
    await tester.pumpWidget(const AgencyOpsApp());

    // Verify that the login text exists.
    expect(find.text('SparxTexh Agency Hub'), findsOneWidget);
  });
}

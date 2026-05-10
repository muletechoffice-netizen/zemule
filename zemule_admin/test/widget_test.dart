import 'package:flutter_test/flutter_test.dart';

import 'package:zemule_admin/screens/not_found_screen.dart';

void main() {
  testWidgets('NotFoundApp renders not found text', (WidgetTester tester) async {
    await tester.pumpWidget(const NotFoundApp());
    expect(find.text('Not found'), findsOneWidget);
  });
}

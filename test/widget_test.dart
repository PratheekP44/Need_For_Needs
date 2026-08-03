import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:need_for_needs/app.dart';

void main() {
  testWidgets('App boots into splash UI skeleton', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NeedForNeedsApp(),
      ),
    );

    expect(find.text('Need For Needs'), findsOneWidget);
    expect(find.textContaining('Campus Essentials'), findsOneWidget);

    // Allow splash auto-navigation timer without settling forever.
    await tester.pump(const Duration(milliseconds: 1700));
  });
}

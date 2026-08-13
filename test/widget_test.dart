import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:need_for_needs/app.dart';
import 'package:need_for_needs/core/widgets/app_brand.dart';
import 'package:need_for_needs/core/widgets/locker_init_indicator.dart';

void main() {
  testWidgets('App boots into splash UI skeleton', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NeedForNeedsApp(),
      ),
    );

    expect(find.byType(AppBrand), findsOneWidget);
    expect(find.byType(LockerInitIndicator), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == BrandAssets.locker,
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == BrandAssets.title,
      ),
      findsWidgets,
    );
    expect(find.textContaining('Campus'), findsNothing);
    expect(find.textContaining('Campus Locker'), findsNothing);
    expect(find.textContaining('Campus lockers'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Allow splash auto-navigation timer without settling forever.
    await tester.pump(const Duration(milliseconds: 2300));
  });
}

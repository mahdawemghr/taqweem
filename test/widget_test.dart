import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/app.dart';
import 'package:taqweem/data/poster_repository.dart';
import 'package:taqweem/state/providers.dart';

void main() {
  testWidgets('app opens on the RTL home with the empty state', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('taqweem_smoke');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWith((ref) async => PosterRepository(tmp)),
        ],
        child: const TaqweemApp(),
      ),
    );
    // Loading the (empty) drafts folder is real file IO: let real time pass
    // and pump until the provider settles.
    for (
      var i = 0;
      i < 50 && find.text('لا توجد تقاويم بعد').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('تقاويمي'), findsOneWidget);
    expect(find.text('لا توجد تقاويم بعد'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
  });
}

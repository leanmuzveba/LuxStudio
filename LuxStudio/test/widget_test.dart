import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luxstudio/main.dart';

void main() {
  testWidgets('App boots to the import screen', (tester) async {
    await tester.pumpWidget(const LuxStudioApp());

    expect(find.text('Import your sermon'), findsOneWidget);
    expect(find.text('Choose video from device'), findsOneWidget);
  });

  testWidgets('Starting an import shows the processing pipeline', (tester) async {
    await tester.pumpWidget(const LuxStudioApp());

    await tester.tap(find.text('Choose video from device'));
    await tester.pump();

    expect(find.text('Processing your video'), findsOneWidget);
    // "Removing silence" legitimately appears twice: once as the active-step
    // heading, once as the first row in the step checklist below it.
    expect(find.text('Removing silence'), findsNWidgets(2));
  });

  testWidgets('MaterialApp uses the dark LuxStudio theme', (tester) async {
    await tester.pumpWidget(const LuxStudioApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
  });
}

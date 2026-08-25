import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luxstudio/main.dart';
import 'package:luxstudio/state/app_state.dart';
import 'package:luxstudio/services/project_store.dart';

/// A fresh [AppState] backed by a temp-directory [ProjectStore], so tests
/// never touch the real `path_provider` platform channel (which has no
/// implementation under plain `flutter test`) or the developer's actual
/// app-documents folder.
AppState buildTestAppState() {
  final tempDir = Directory.systemTemp.createTempSync('luxstudio_test_');
  return AppState(
    projectStore: ProjectStore(documentsDirProvider: () async => tempDir),
  );
}

/// The app briefly shows a splash screen (an indeterminate spinner —
/// `pumpAndSettle` would never converge on it) while it checks for a
/// project to recover. A couple of frames is enough to let that resolve
/// (there's nothing to recover in a fresh temp dir, and ProjectStore uses
/// synchronous file I/O — see its doc) and the screen swap happen.
Future<void> pumpApp(WidgetTester tester, AppState appState) async {
  await tester.pumpWidget(LuxStudioApp(appState: appState));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('App boots to the import screen', (tester) async {
    await pumpApp(tester, buildTestAppState());

    expect(find.text('Import your sermon'), findsOneWidget);
    expect(find.text('Choose video from device'), findsOneWidget);
  });

  testWidgets('Starting an import shows the processing pipeline', (tester) async {
    await pumpApp(tester, buildTestAppState());

    await tester.tap(find.text('Choose video from device'));
    await tester.pump();

    expect(find.text('Processing your video'), findsOneWidget);
    // "Removing silence" legitimately appears twice: once as the active-step
    // heading, once as the first row in the step checklist below it.
    expect(find.text('Removing silence'), findsNWidgets(2));
  });

  testWidgets('MaterialApp uses the dark LuxStudio theme', (tester) async {
    await pumpApp(tester, buildTestAppState());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
  });
}

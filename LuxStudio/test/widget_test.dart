import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luxstudio/main.dart';
import 'package:luxstudio/services/api_client.dart';
import 'package:luxstudio/services/media_import_service.dart';
import 'package:luxstudio/state/app_state.dart';

/// A fake backend HTTP client so tests never make a real network call —
/// `flutter test` has no backend running. Only `POST /projects` (the one
/// call the tested flows actually trigger) returns a canned response;
/// anything else gets a harmless empty JSON object.
ApiClient buildTestApiClient() {
  final mockClient = http_testing.MockClient.streaming((request, bodyStream) async {
    if (request.method == 'POST' && request.url.path == '/projects') {
      final body = jsonEncode({
        'id': 'test-project-id',
        'durationMs': 300000,
        'width': 1080,
        'height': 1920,
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  });
  return ApiClient(httpClient: mockClient);
}

/// A fresh [AppState] backed by an in-memory (mocked) `shared_preferences`
/// store, so tests never touch real browser/platform storage, and a fake
/// [ApiClient] so no real backend call is made.
AppState buildTestAppState() {
  SharedPreferences.setMockInitialValues({});
  return AppState(apiClient: buildTestApiClient());
}

/// A [MediaImportService] that "picks" a small real dummy file from a temp
/// dir instead of opening the real native file picker, and uploads it via
/// the same fake backend client as [buildTestAppState].
MediaImportService buildTestMediaImportService() {
  final pickedFile = File(
    '${Directory.systemTemp.createTempSync('luxstudio_test_pick_').path}/sermon.mp4',
  )..writeAsBytesSync([0]);

  return MediaImportService(
    apiClient: buildTestApiClient(),
    pickFile: () async => PickedMediaFile(
      name: 'sermon.mp4',
      path: pickedFile.path,
      readAsBytes: () async => pickedFile.readAsBytesSync(),
    ),
  );
}

/// The app briefly shows a splash screen (an indeterminate spinner —
/// `pumpAndSettle` would never converge on it) while it checks for a
/// project to recover. A couple of frames is enough to let that resolve
/// (there's nothing to recover in a fresh mocked store) and the screen
/// swap happen.
Future<void> pumpApp(
  WidgetTester tester,
  AppState appState, {
  MediaImportService? mediaImportService,
}) async {
  await tester.pumpWidget(LuxStudioApp(
    appState: appState,
    mediaImportService: mediaImportService ?? buildTestMediaImportService(),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('App boots to the Home dashboard', (tester) async {
    await pumpApp(tester, buildTestAppState());

    expect(find.text('LuxStudio'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('New Project opens the import screen', (tester) async {
    await pumpApp(tester, buildTestAppState());

    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();

    expect(find.text('Import Video'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
  });

  testWidgets('Picking a video from Import goes straight to the editor', (tester) async {
    await pumpApp(tester, buildTestAppState());

    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Device'));
    // The (fake) import does its own async work (upload) before
    // AppState.startImport is called and the screen navigates. Bounded
    // pumps rather than pumpAndSettle: the editor's video preview shows
    // an indeterminate spinner while its (real, unmockable under
    // `flutter test`) VideoPlayerController never finishes initializing,
    // which pumpAndSettle would wait on forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Remove Silence'), findsOneWidget);
  });

  testWidgets('MaterialApp uses the dark LuxStudio theme', (tester) async {
    await pumpApp(tester, buildTestAppState());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
  });
}

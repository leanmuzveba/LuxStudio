import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luxstudio/main.dart';
import 'package:luxstudio/models/ai_clip.dart';
import 'package:luxstudio/models/transcript_segment.dart';
import 'package:luxstudio/models/video_project.dart';
import 'package:luxstudio/services/api_client.dart';
import 'package:luxstudio/services/media_import_service.dart';
import 'package:luxstudio/state/app_state.dart';

/// A fake backend HTTP client so tests never make a real network call —
/// `flutter test` has no backend running. Handles the calls the tested
/// flows actually trigger (project create, analyse pipeline start/poll —
/// the pipeline reports itself already "done" on the first poll, so tests
/// don't need to simulate multiple polling rounds); anything else gets a
/// harmless empty JSON object.
ApiClient buildTestApiClient() {
  final mockClient = http_testing.MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;

    if (request.method == 'POST' && path == '/projects') {
      return _jsonResponse({
        'id': 'test-project-id',
        'durationMs': 300000,
        'width': 1080,
        'height': 1920,
      });
    }
    if (request.method == 'POST' && path.endsWith('/analyse')) {
      return _jsonResponse({'status': 'running', 'step': null, 'percent': 0, 'error': null});
    }
    if (request.method == 'GET' && path.endsWith('/analyse/status')) {
      return _jsonResponse({'status': 'done', 'step': 'captioning', 'percent': 100, 'error': null});
    }
    if (request.method == 'POST' && path == '/auth/verify') {
      final bytes = await bodyStream.expand((chunk) => chunk).toList();
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (body['passcode'] == _testPasscode) {
        return _jsonResponse({'ok': true});
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'detail': 'Incorrect passcode'}))),
        401,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.method == 'GET' && path == '/library/folders') {
      return _jsonListResponse([
        {'id': 'f1', 'name': 'Sermon B-Roll'},
      ]);
    }
    if (request.method == 'GET' && path == '/library/assets') {
      return _jsonListResponse([
        {
          'id': 'a1',
          'filename': 'sermon.mp4',
          'folder_id': null,
          'size_bytes': 1048576,
          'durationMs': 60000,
          'width': 1920,
          'height': 1080,
        },
      ]);
    }
    if (request.method == 'GET' && path == '/library/quota') {
      return _jsonResponse({'used_bytes': 1048576, 'limit_bytes': 21474836480});
    }
    if (request.method == 'GET' && path == '/exports/history') {
      return _jsonListResponse([
        {
          'id': 'e1',
          'status': 'done',
          'projectTitle': 'Sunday Sermon',
          'clipTitle': 'The Walk of Faith',
          'durationMs': 42000,
          'sizeBytes': 5242880,
          'error': null,
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          'downloadUrl': '/exports/history/e1/download',
        },
      ]);
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  });
  return ApiClient(httpClient: mockClient);
}

/// The fake backend's one accepted passcode — see [buildTestApiClient]'s
/// `/auth/verify` handling.
const _testPasscode = 'letmein';

http.StreamedResponse _jsonResponse(Map<String, dynamic> body) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json'},
    );

http.StreamedResponse _jsonListResponse(List<dynamic> body) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json'},
    );

/// A fresh [AppState] backed by an in-memory (mocked) `shared_preferences`
/// store, so tests never touch real browser/platform storage, and a fake
/// [ApiClient] so no real backend call is made. Pre-unlocked (past the
/// passcode gate) by default, since most tests exercise the app past
/// login — see [buildLockedTestAppState] for tests of the gate itself.
AppState buildTestAppState() {
  SharedPreferences.setMockInitialValues({'auth_unlocked': true});
  return AppState(apiClient: buildTestApiClient());
}

/// Same as [buildTestAppState] but starting locked, for tests of
/// [LoginScreen] itself.
AppState buildLockedTestAppState() {
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
    expect(find.text('New Sermon Project'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('New Project opens the import screen', (tester) async {
    await pumpApp(tester, buildTestAppState());

    await tester.tap(find.text('New Sermon Project'));
    await tester.pumpAndSettle();

    expect(find.text('Import Video'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
  });

  testWidgets('Picking a video from Import goes to the Analyse screen', (tester) async {
    await pumpApp(tester, buildTestAppState());

    await tester.tap(find.text('New Sermon Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Device'));
    // The (fake) import does its own async work (upload) before
    // AppState.startImport is called and the screen navigates. Bounded
    // pumps rather than pumpAndSettle: AnalyseScreen's pipeline polling
    // loop sleeps between polls, which pumpAndSettle would wait on forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Analyzing Sermon'), findsOneWidget);

    // Let runAnalysePipeline()'s first poll (after an 800ms delay) land —
    // the fake backend reports itself already "done" on that first poll.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.text('Open Editor'), findsOneWidget);
  });

  testWidgets('MaterialApp uses the dark LuxStudio theme', (tester) async {
    await pumpApp(tester, buildTestAppState());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
  });

  testWidgets('A locked device shows the passcode gate instead of Home', (tester) async {
    await pumpApp(tester, buildLockedTestAppState());

    expect(find.text('UNLOCK STUDIO'), findsOneWidget);
    expect(find.text('New Sermon Project'), findsNothing);
  });

  testWidgets('An incorrect passcode shows an error and stays locked', (tester) async {
    await pumpApp(tester, buildLockedTestAppState());

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('UNLOCK STUDIO'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect passcode.'), findsOneWidget);
    expect(find.text('New Sermon Project'), findsNothing);
  });

  testWidgets('The correct passcode unlocks straight into Home', (tester) async {
    await pumpApp(tester, buildLockedTestAppState());

    await tester.enterText(find.byType(TextField), 'letmein');
    await tester.tap(find.text('UNLOCK STUDIO'));
    await tester.pumpAndSettle();

    expect(find.text('New Sermon Project'), findsOneWidget);
  });

  testWidgets('A desktop-wide window shows the sidebar shell instead of the bottom nav', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, buildTestAppState());

    expect(find.text('Media Library'), findsOneWidget);
    expect(find.text('AI Highlights'), findsOneWidget);
    expect(find.text('New Sermon Project'), findsNothing);
  });

  testWidgets('Desktop Editor shows the real project and AI clip data, not mockup placeholders', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final appState = buildTestAppState();
    appState.startImport(VideoProject(
      id: 'p1',
      fileName: 'sermon.mp4',
      backendProjectId: 'test-project-id',
      rawDuration: const Duration(minutes: 30),
      processedDuration: const Duration(minutes: 28),
      width: 1080,
      height: 1920,
      importedAt: DateTime(2026, 1, 1),
    ));
    appState.suggestedClips.add(AiClip(
      id: 'c1',
      title: 'The Power of Community',
      start: const Duration(minutes: 4, seconds: 22),
      end: const Duration(minutes: 5, seconds: 20),
      viralScore: 92,
      reason: 'Strong emotional hook',
      category: 'viral',
    ));

    await pumpApp(tester, appState);
    await tester.pump(const Duration(milliseconds: 300));

    // Shows in both the header title and the sidebar's "Current Project" card.
    expect(find.text('sermon'), findsNWidgets(2));
    expect(find.text('AI Clip Insights'), findsOneWidget);
    expect(find.text('The Power of Community'), findsOneWidget);
    expect(find.text('No project loaded yet — go import a video first.'), findsNothing);
  });

  testWidgets('Desktop Media Library shows real folders and assets from the backend', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, buildTestAppState());

    await tester.tap(find.text('Media Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Sermon B-Roll'), findsOneWidget);
    expect(find.text('sermon.mp4'), findsOneWidget);
    expect(find.text('No media yet — upload a sermon video to get started.'), findsNothing);
  });

  testWidgets('Desktop AI Highlights shows real clips grouped into reels by category', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final appState = buildTestAppState();
    appState.startImport(VideoProject(
      id: 'p1',
      fileName: 'sermon.mp4',
      backendProjectId: 'test-project-id',
      rawDuration: const Duration(minutes: 30),
      processedDuration: const Duration(minutes: 28),
      width: 1080,
      height: 1920,
      importedAt: DateTime(2026, 1, 1),
    ));
    appState.suggestedClips.addAll([
      AiClip(
        id: 'c1',
        title: 'The Walk of Faith Metaphor',
        start: const Duration(minutes: 12, seconds: 15),
        end: const Duration(minutes: 13, seconds: 7),
        viralScore: 92,
        reason: 'Strong emotional hook',
        category: 'Strong Hooks',
      ),
      AiClip(
        id: 'c2',
        title: 'The Community Effect',
        start: const Duration(minutes: 5, seconds: 10),
        end: const Duration(minutes: 5, seconds: 45),
        viralScore: 88,
        reason: 'Trending topic reference',
        category: 'Trending Topic',
      ),
    ]);

    await pumpApp(tester, appState);

    await tester.tap(find.text('AI Highlights'));
    await tester.pump();

    expect(find.text('Detected Viral Segments'), findsOneWidget);
    expect(find.text('The Walk of Faith Metaphor'), findsOneWidget);
    expect(find.text('The Community Effect'), findsOneWidget);
    expect(find.text('Strong Hooks'), findsOneWidget);
    expect(find.text('Trending Topic'), findsOneWidget);
    expect(find.text('2 clips found'), findsOneWidget);
  });

  testWidgets('Desktop Subtitles shows the real transcript and edits the real caption style', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final appState = buildTestAppState();
    appState.startImport(VideoProject(
      id: 'p1',
      fileName: 'sermon.mp4',
      backendProjectId: 'test-project-id',
      rawDuration: const Duration(minutes: 30),
      processedDuration: const Duration(minutes: 28),
      width: 1080,
      height: 1920,
      importedAt: DateTime(2026, 1, 1),
    ));
    appState.transcript.add(TranscriptSegment(
      id: 's1',
      start: Duration.zero,
      end: const Duration(seconds: 4),
      text: 'Good morning everyone.',
    ));

    await pumpApp(tester, appState);

    await tester.tap(find.text('Subtitles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Good morning everyone.'), findsWidgets);
    expect(appState.captionStyle.italic, isFalse);

    await tester.tap(find.byTooltip('Italic'));
    await tester.pump();

    expect(appState.captionStyle.italic, isTrue);
  });

  testWidgets('Desktop Subtitles splits a segment at the cursor on Enter', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final appState = buildTestAppState();
    appState.startImport(VideoProject(
      id: 'p1',
      fileName: 'sermon.mp4',
      backendProjectId: 'test-project-id',
      rawDuration: const Duration(minutes: 30),
      processedDuration: const Duration(minutes: 28),
      width: 1080,
      height: 1920,
      importedAt: DateTime(2026, 1, 1),
    ));
    appState.transcript.add(TranscriptSegment(
      id: 's1',
      start: Duration.zero,
      end: const Duration(seconds: 10),
      text: 'Good morning everyone welcome to the service.',
    ));

    await pumpApp(tester, appState);

    await tester.tap(find.text('Subtitles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap the transcript line to enter edit mode (the same text also
    // appears, smaller, in the timeline strip below — target the pane's).
    // A blinking-cursor TextField never "settles", so pump a bounded number
    // of frames rather than pumpAndSettle.
    await tester.tap(find.byKey(const ValueKey('s1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Place the cursor right after "Good morning" and press Enter — should
    // split into two segments there rather than inserting a newline.
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection.collapsed(offset: 12);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(appState.transcript.length, 2);
    expect(appState.transcript[0].id, 's1');
    expect(appState.transcript[0].text, 'Good morning');
    expect(appState.transcript[1].text, 'everyone welcome to the service.');
    expect(appState.transcript[0].end, appState.transcript[1].start);
    expect(appState.transcript[1].end, const Duration(seconds: 10));

    // The new second segment opens for editing automatically (focus moves
    // to it, matching "the right side moves to the next line").
    expect(find.text('Good morning'), findsWidgets);
  });

  testWidgets('Desktop Exports shows the real export history from the backend', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final appState = buildTestAppState();

    await pumpApp(tester, appState);

    await tester.tap(find.text('Exports'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('The Walk of Faith'), findsOneWidget);
    expect(find.textContaining('Sunday Sermon'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);
    expect(
      find.text('No exports yet — export a clip from the Editor, AI Highlights, or Share to see it here.'),
      findsNothing,
    );
  });

  testWidgets('Desktop Settings shows the real seeded church settings and switches sections', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, buildTestAppState());

    // The sidebar's pinned "Settings" entry (distinct from a nav item of
    // the same label that only exists inside the settings pane itself).
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Defaults to the first section, Church Profile, seeded from
    // BrandSettings.seeded (no real backend/prefs data in this test). The
    // left nav always lists every section label, so assert on
    // section-specific *content*, not the nav labels themselves.
    expect(find.text('Higherlife Commission'), findsOneWidget);
    expect(find.text('#wordsofwisdom'), findsNothing);

    await tester.tap(find.text('Default Hashtags'));
    await tester.pump();

    expect(find.text('#wordsofwisdom'), findsOneWidget);
    expect(find.text('Higherlife Commission'), findsNothing);
  });
}

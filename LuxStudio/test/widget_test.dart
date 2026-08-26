import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luxstudio/main.dart';
import 'package:luxstudio/services/ffmpeg_service.dart';
import 'package:luxstudio/services/media_import_service.dart';
import 'package:luxstudio/services/project_store.dart';
import 'package:luxstudio/state/app_state.dart';

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

/// Fakes ffprobe's result so tests never touch the real native plugin.
class _FakeFfmpegService extends FfmpegService {
  @override
  Future<MediaInfo> probe(String path) async => const MediaInfo(
        duration: Duration(minutes: 5),
        width: 1080,
        height: 1920,
      );
}

/// A [MediaImportService] that "picks" a small real dummy file from a temp
/// dir (so the direct-file-copy path has something real to copy) instead
/// of opening the real native file picker, and fakes the ffprobe step too.
MediaImportService buildTestMediaImportService() {
  final pickedFile = File(
    '${Directory.systemTemp.createTempSync('luxstudio_test_pick_').path}/sermon.mp4',
  )..writeAsBytesSync([0]);

  return MediaImportService(
    ffmpegService: _FakeFfmpegService(),
    documentsDirProvider: () async => Directory.systemTemp.createTempSync('luxstudio_test_docs_'),
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
/// (there's nothing to recover in a fresh temp dir, and ProjectStore uses
/// synchronous file I/O — see its doc) and the screen swap happen.
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

    expect(find.text('Import your sermon'), findsOneWidget);
    expect(find.text('Choose video from device'), findsOneWidget);
  });

  testWidgets('Starting an import shows the processing pipeline', (tester) async {
    await pumpApp(tester, buildTestAppState());

    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose video from device'));
    // The (fake) import does its own async work (copy + probe) before
    // AppState.startImport is called and the pipeline UI appears.
    await tester.pump();
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

import 'package:flutter/material.dart';

import 'screens/ai_clips_screen.dart';
import 'screens/export_share_screen.dart';
import 'screens/import_processing_screen.dart';
import 'screens/video_editor_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LuxStudioApp());
}

class LuxStudioApp extends StatefulWidget {
  const LuxStudioApp({super.key});

  @override
  State<LuxStudioApp> createState() => _LuxStudioAppState();
}

class _LuxStudioAppState extends State<LuxStudioApp> {
  final AppState appState = AppState();

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: appState,
      child: MaterialApp(
        title: 'LuxStudio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: AppRoutes.import,
        routes: {
          AppRoutes.import: (_) => const ImportProcessingScreen(),
          AppRoutes.editor: (_) => const VideoEditorScreen(),
          AppRoutes.clips: (_) => const AiClipsScreen(),
          AppRoutes.export: (_) => const ExportShareScreen(),
        },
      ),
    );
  }
}

/// Route names for the four-screen LuxStudio flow.
class AppRoutes {
  AppRoutes._();
  static const import = '/';
  static const editor = '/editor';
  static const clips = '/clips';
  static const export = '/export';
}

/// Makes the single [AppState] instance available to the whole widget
/// tree without pulling in a state-management dependency. Screens read it
/// via `AppStateScope.of(context)` and rebuild using [AnimatedBuilder].
class AppStateScope extends InheritedWidget {
  final AppState appState;

  const AppStateScope({
    super.key,
    required this.appState,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context');
    return scope!.appState;
  }

  @override
  bool updateShouldNotify(AppStateScope oldWidget) =>
      appState != oldWidget.appState;
}

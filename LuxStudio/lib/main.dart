import 'package:flutter/material.dart';

import 'screens/ai_clips_screen.dart';
import 'screens/export_share_screen.dart';
import 'screens/import_processing_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/video_editor_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LuxStudioApp());
}

class LuxStudioApp extends StatefulWidget {
  /// [appState] lets tests inject one backed by a fake [ProjectStore]
  /// (real `path_provider` calls need a platform channel with no
  /// implementation under plain `flutter test`). Defaults to a real one.
  const LuxStudioApp({super.key, AppState? appState}) : _injectedAppState = appState;

  final AppState? _injectedAppState;

  @override
  State<LuxStudioApp> createState() => _LuxStudioAppState();
}

class _LuxStudioAppState extends State<LuxStudioApp> {
  late final AppState appState = widget._injectedAppState ?? AppState();
  bool _checkedRecovery = false;

  @override
  void initState() {
    super.initState();
    // Recover the last active project (if any) before showing a screen, so
    // an unexpected close doesn't lose the user's work. Best-effort — see
    // ProjectStore's doc for why this never throws.
    appState.tryRecoverLastProject().whenComplete(() {
      if (mounted) setState(() => _checkedRecovery = true);
    });
  }

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
        home: !_checkedRecovery
            ? const _SplashScreen()
            : (appState.project != null && appState.processingComplete)
                ? const VideoEditorScreen()
                : const ImportProcessingScreen(),
        routes: {
          // AppRoutes.import ('/') is handled via `home` above, not here —
          // MaterialApp forbids routes containing the default route name
          // when `home` is also set. Nothing navigates back to it by name.
          AppRoutes.editor: (_) => const VideoEditorScreen(),
          AppRoutes.clips: (_) => const AiClipsScreen(),
          AppRoutes.export: (_) => const ExportShareScreen(),
          AppRoutes.settings: (_) => const SettingsScreen(),
        },
      ),
    );
  }
}

/// Shown briefly on launch while [AppState.tryRecoverLastProject] checks
/// for a project to resume.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
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
  static const settings = '/settings';
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

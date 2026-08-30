import 'package:flutter/material.dart';

import 'screens/ai_clips_screen.dart';
import 'screens/branding_screen.dart';
import 'screens/captions_screen.dart';
import 'screens/export_share_screen.dart';
import 'screens/import_screen.dart';
import 'screens/silence_screen.dart';
import 'screens/social_screen.dart';
import 'screens/video_editor_screen.dart';
import 'services/media_import_service.dart';
import 'state/app_state.dart';
import 'theme/lux_theme.dart';
import 'widgets/bottom_nav_scaffold.dart';

void main() {
  runApp(const LuxStudioApp());
}

class LuxStudioApp extends StatefulWidget {
  /// [appState] and [mediaImportService] let tests inject fakes (a real
  /// `file_picker` call needs a platform channel with no implementation
  /// under plain `flutter test`, and a real [AppState]/[MediaImportService]
  /// would hit the actual backend). Both default to real implementations.
  const LuxStudioApp({super.key, AppState? appState, MediaImportService? mediaImportService})
      : _injectedAppState = appState,
        _injectedMediaImportService = mediaImportService;

  final AppState? _injectedAppState;
  final MediaImportService? _injectedMediaImportService;

  @override
  State<LuxStudioApp> createState() => _LuxStudioAppState();
}

class _LuxStudioAppState extends State<LuxStudioApp> {
  late final AppState appState = widget._injectedAppState ?? AppState();
  late final MediaImportService mediaImportService =
      widget._injectedMediaImportService ?? MediaImportService();
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
    appState.reloadBrandSettings();
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
        theme: LuxTheme.dark,
        home: !_checkedRecovery ? const _SplashScreen() : const BottomNavScaffold(),
        routes: {
          AppRoutes.import: (_) => ImportScreen(mediaImportService: mediaImportService),
          AppRoutes.editor: (_) => const VideoEditorScreen(),
          AppRoutes.silence: (_) => const SilenceScreen(),
          AppRoutes.captions: (_) => const CaptionsScreen(),
          AppRoutes.clips: (_) => const AiClipsScreen(),
          AppRoutes.social: (_) => const SocialScreen(),
          AppRoutes.branding: (_) => const BrandingScreen(),
          AppRoutes.export: (_) => const ExportShareScreen(),
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

/// Route names for the pushed (non-tab) screens. Home/Branding/Settings
/// tabs live inside [BottomNavScaffold], set as `home` above.
class AppRoutes {
  AppRoutes._();
  static const import = '/import';
  static const editor = '/editor';
  static const silence = '/silence';
  static const captions = '/captions';
  static const clips = '/clips';
  static const social = '/social';
  static const branding = '/branding';
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

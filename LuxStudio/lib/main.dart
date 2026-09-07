import 'package:flutter/material.dart';

import 'screens/ai_clips_screen.dart';
import 'screens/analyse_screen.dart';
import 'screens/import_screen.dart';
import 'screens/login_screen.dart';
import 'screens/share_screen.dart';
import 'screens/video_editor_screen.dart';
import 'services/media_import_service.dart';
import 'state/app_state.dart';
import 'theme/breakpoints.dart';
import 'theme/lux_theme.dart';
import 'widgets/bottom_nav_scaffold.dart';
import 'widgets/desktop_shell_scaffold.dart';
import 'widgets/phone_shell.dart';

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
  bool _checkedAuth = false;

  @override
  void initState() {
    super.initState();
    // Recover the last active project (if any) before showing a screen, so
    // an unexpected close doesn't lose the user's work. Best-effort — see
    // ProjectStore's doc for why this never throws.
    appState.tryRecoverLastProject().whenComplete(() {
      if (mounted) setState(() => _checkedRecovery = true);
    });
    // Whether this device already passed the shared church-passcode gate
    // (see AppState.loadAuthStatus/LoginScreen) — checked in parallel with
    // recovery, both gate leaving the splash screen below.
    appState.loadAuthStatus().whenComplete(() {
      if (mounted) setState(() => _checkedAuth = true);
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
        // Desktop-width windows get [DesktopShellScaffold] full-bleed (its
        // own sidebar + content pane); everything else — [BottomNavScaffold]
        // and the "new project" flow routes below, none of which have a
        // desktop treatment yet — keeps the ui_kit's original "phone shell"
        // cap (max-width 430px, centered; see ui_kit/*/styles.css's `.app {
        // max-width: 430px; margin: 0 auto; }` and CLAUDE.md's
        // platform-decision note) via [PhoneShell], applied per-route below
        // rather than once here, so it doesn't also squeeze the desktop
        // shell. See PIVOT_PLAN_V2.md Phase 24.
        //
        // Below the splash gate, an [AnimatedBuilder] on [appState] picks
        // [LoginScreen] vs [_ResponsiveHome] by [AppState.isUnlocked] so a
        // successful passcode check swaps straight to the app with no
        // navigation call needed (see PIVOT_PLAN_V2.md Phase 25).
        home: !_checkedRecovery || !_checkedAuth
            ? const _SplashScreen()
            : AnimatedBuilder(
                animation: appState,
                builder: (context, _) =>
                    appState.isUnlocked ? const _ResponsiveHome() : const LoginScreen(),
              ),
        routes: {
          AppRoutes.import: (_) => PhoneShell(child: ImportScreen(mediaImportService: mediaImportService)),
          AppRoutes.analyse: (_) => const PhoneShell(child: AnalyseScreen()),
          AppRoutes.editor: (_) => const PhoneShell(child: VideoEditorScreen()),
          AppRoutes.clips: (_) => const PhoneShell(child: AiClipsScreen()),
          AppRoutes.share: (_) => const PhoneShell(child: ShareScreen()),
        },
      ),
    );
  }
}

/// Shown briefly on launch while [AppState.tryRecoverLastProject] and
/// [AppState.loadAuthStatus] both resolve — matches `ui_kit/auth/index.html`
/// and `auth_desktop/index.html`'s splash panel (logo + wordmark + loader).
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/branding/icon.png', width: 72, height: 72),
            const SizedBox(height: 18),
            RichText(
              text: TextSpan(children: [
                TextSpan(text: 'Lux', style: LuxText.sora(size: 32, color: LuxColors.textPrimary)),
                TextSpan(text: 'Studio', style: LuxText.sora(size: 32, color: LuxColors.gold)),
              ]),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: LuxColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the app's root shell by window width once past splash/recovery —
/// see PIVOT_PLAN_V2.md Phase 24 and [Breakpoints].
class _ResponsiveHome extends StatelessWidget {
  const _ResponsiveHome();

  @override
  Widget build(BuildContext context) {
    return Breakpoints.isDesktop(context)
        ? const DesktopShellScaffold()
        : const PhoneShell(child: BottomNavScaffold());
  }
}

/// Route names for the pushed (non-tab) screens. Home/Editor/Clips/
/// Settings tabs live inside [BottomNavScaffold], set as `home` above —
/// Branding is no longer its own screen/tab, folded into Settings.
class AppRoutes {
  AppRoutes._();
  static const import = '/import';
  static const analyse = '/analyse';
  static const editor = '/editor';
  static const clips = '/clips';
  static const share = '/share';
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

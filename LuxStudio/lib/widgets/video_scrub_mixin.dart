import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Shared playback/seek plumbing for a screen that scrubs a project's video
/// via [VideoPlayerController] — factored out so the mobile and desktop
/// Editor screens (see PIVOT_PLAN_V2.md Phase 26) share the same controller
/// lifecycle and seek-clamping logic instead of each reimplementing it.
mixin VideoScrubMixin<T extends StatefulWidget> on State<T> {
  VideoPlayerController? controller;
  String? _controllerUrl;
  Duration position = Duration.zero;

  /// (Re)creates [controller] for [url] if it's not already pointed at it —
  /// safe to call on every build.
  void ensureController(String url) {
    if (_controllerUrl == url) return;
    controller?.removeListener(_onControllerUpdate);
    controller?.dispose();

    _controllerUrl = url;
    final newController = VideoPlayerController.networkUrl(Uri.parse(url));
    controller = newController;
    newController.addListener(_onControllerUpdate);
    newController.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {
      // Preview stays in its not-yet-initialized state (spinner) rather
      // than crashing the editor on an unsupported/corrupt file.
      if (mounted) setState(() {});
    });
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final c = controller;
    if (c == null) return;
    setState(() => position = c.value.position);
  }

  void togglePlayback() {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  void seekTo(Duration target) {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > c.value.duration ? c.value.duration : target);
    c.seekTo(clamped);
  }

  /// Call from the widget's own [State.dispose] — not overridden here
  /// directly so each screen keeps control of its own disposal order.
  void disposeVideoScrub() {
    controller?.removeListener(_onControllerUpdate);
    controller?.dispose();
  }
}

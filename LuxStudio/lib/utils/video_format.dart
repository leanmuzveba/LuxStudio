/// Video containers LuxStudio's import pipeline accepts.
///
/// Every preview in this app (Analyse, Editor, Clips) plays the video
/// through `video_player`, which on Flutter Web wraps the browser's native
/// `<video>` element — and Chrome's media pipeline doesn't demux Matroska
/// (.mkv), a very common sermon-recording container. Rather than reject it,
/// the backend's automatic analyse pipeline (already run on every import —
/// see AnalyseScreen/AppState.runAnalysePipeline) now always re-encodes a
/// non-mp4/mov source into a browser-safe `working.mp4` before the editor
/// ever tries to play it (backend/app/routers/analyse.py's `force_reencode`).
/// So .mkv is accepted here — it just isn't *directly* previewable.
const supportedVideoExtensions = {'mp4', 'mov', 'mkv'};

bool isSupportedVideoFilename(String filename) {
  final ext = _extensionOf(filename);
  return ext != null && supportedVideoExtensions.contains(ext);
}

String unsupportedVideoFormatMessage(String filename) {
  final ext = _extensionOf(filename);
  final label = ext == null ? 'This file' : '".$ext" files';
  return '$label aren\'t supported — please use MP4, MOV, or MKV.';
}

String? _extensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot == -1 || dot == filename.length - 1) return null;
  return filename.substring(dot + 1).toLowerCase();
}

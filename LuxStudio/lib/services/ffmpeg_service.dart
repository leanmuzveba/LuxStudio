import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';

/// Duration and pixel dimensions read from a media file via ffprobe.
class MediaInfo {
  final Duration duration;
  final int width;
  final int height;

  const MediaInfo({required this.duration, required this.width, required this.height});
}

/// Wraps `ffmpeg_kit_flutter_new` for the pieces LuxStudio needs: probing
/// media metadata now, and — in later phases — silence detection/removal,
/// cropping/scaling, caption/branding burn-in, and export.
class FfmpegService {
  Future<MediaInfo> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) {
      final failLog = await session.getFailStackTrace();
      throw StateError('ffprobe could not read $path${failLog != null ? ': $failLog' : ''}');
    }

    final durationSeconds = double.tryParse(info.getDuration() ?? '') ?? 0;
    StreamInformation? videoStream;
    for (final stream in info.getStreams()) {
      if (stream.getType() == 'video') {
        videoStream = stream;
        break;
      }
    }

    return MediaInfo(
      duration: Duration(milliseconds: (durationSeconds * 1000).round()),
      width: videoStream?.getWidth() ?? 0,
      height: videoStream?.getHeight() ?? 0,
    );
  }
}

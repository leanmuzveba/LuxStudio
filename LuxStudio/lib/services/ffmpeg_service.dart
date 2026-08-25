import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';

import '../models/silence_range.dart';

/// Duration and pixel dimensions read from a media file via ffprobe.
class MediaInfo {
  final Duration duration;
  final int width;
  final int height;

  const MediaInfo({required this.duration, required this.width, required this.height});
}

/// Wraps `ffmpeg_kit_flutter_new` for the pieces LuxStudio needs: probing
/// media metadata, silence detection/removal, and — in later phases —
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

  /// Runs ffmpeg's `silencedetect` audio filter and parses the detected
  /// silent ranges out of its log output. [noiseFloorDb] is how quiet
  /// (dBFS) counts as silence; [minDuration] is the shortest gap worth
  /// flagging.
  Future<List<SilenceRange>> detectSilence(
    String path, {
    double noiseFloorDb = -30,
    Duration minDuration = const Duration(milliseconds: 500),
  }) async {
    final session = await FFmpegKit.executeWithArguments([
      '-i', path,
      '-af', 'silencedetect=noise=${noiseFloorDb}dB:d=${minDuration.inMilliseconds / 1000}',
      '-f', 'null',
      '-',
    ]);
    final logs = await session.getAllLogsAsString() ?? '';
    return _parseSilenceLog(logs);
  }

  List<SilenceRange> _parseSilenceLog(String logs) {
    final startPattern = RegExp(r'silence_start:\s*([\d.]+)');
    final endPattern = RegExp(r'silence_end:\s*([\d.]+)');
    final ranges = <SilenceRange>[];
    double? pendingStart;

    for (final line in logs.split('\n')) {
      final startMatch = startPattern.firstMatch(line);
      if (startMatch != null) {
        pendingStart = double.tryParse(startMatch.group(1)!);
        continue;
      }
      final endMatch = endPattern.firstMatch(line);
      if (endMatch != null && pendingStart != null) {
        final end = double.tryParse(endMatch.group(1)!);
        if (end != null) {
          ranges.add(SilenceRange(
            start: Duration(milliseconds: (pendingStart * 1000).round()),
            end: Duration(milliseconds: (end * 1000).round()),
          ));
        }
        pendingStart = null;
      }
    }
    return ranges;
  }

  /// Produces a new file at [outputPath] with [rangesToRemove] cut out of
  /// [sourcePath] and the remaining audio/video closed up (no gaps). If
  /// [rangesToRemove] is empty, just copies the source through unchanged.
  Future<void> removeRanges({
    required String sourcePath,
    required String outputPath,
    required List<SilenceRange> rangesToRemove,
  }) async {
    if (rangesToRemove.isEmpty) {
      await FFmpegKit.executeWithArguments(['-y', '-i', sourcePath, '-c', 'copy', outputPath]);
      return;
    }

    final expr = 'not(${rangesToRemove.map(_betweenClause).join('+')})';
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i', sourcePath,
      '-vf', 'select=$expr,setpts=N/FRAME_RATE/TB',
      '-af', 'aselect=$expr,asetpts=N/SR/TB',
      outputPath,
    ]);

    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw StateError('ffmpeg silence removal failed (code $returnCode): $logs');
    }
  }

  String _betweenClause(SilenceRange r) => 'between(t,${_seconds(r.start)},${_seconds(r.end)})';

  String _seconds(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);
}

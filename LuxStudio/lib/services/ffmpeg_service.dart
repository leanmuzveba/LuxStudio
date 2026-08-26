import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';

import '../models/silence_range.dart';

/// Parses ffmpeg's `silencedetect` filter log output into ranges. Pure and
/// side-effect-free (no ffmpeg session needed) so it's directly unit
/// testable — see [FfmpegService.detectSilence] for the caller.
List<SilenceRange> parseSilenceLog(String logs) {
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

/// Duration and pixel dimensions read from a media file via ffprobe.
class MediaInfo {
  final Duration duration;
  final int width;
  final int height;

  const MediaInfo({required this.duration, required this.width, required this.height});
}

/// Wraps `ffmpeg_kit_flutter_new` for the pieces LuxStudio needs: probing
/// media metadata, silence detection/removal, and final clip export
/// (crop/scale, caption/branding burn-in).
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
    return parseSilenceLog(logs);
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

  /// Extracts just the audio track to [outputPath] as low-bitrate mono
  /// AAC — small enough to send to Gemini inline for a typical sermon
  /// length, since speech transcription doesn't need music-quality audio.
  Future<void> extractAudio(String sourcePath, String outputPath) async {
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i', sourcePath,
      '-vn',
      '-ac', '1',
      '-b:a', '64k',
      outputPath,
    ]);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw StateError('ffmpeg audio extraction failed (code $returnCode): $logs');
    }
  }

  /// Exports the [start]-[end] range of [sourcePath] as a 1080×1920
  /// vertical clip at [outputPath] — the MVP1 primary export target.
  /// Optionally burns in [subtitlesPath] (an SRT file, timestamps already
  /// relative to [start]) styled by [forceStyle] (an ffmpeg `subtitles`
  /// filter `force_style` value — see [CaptionStyle.assForceStyle] — falls
  /// back to a plain white/outlined default when not given), a logo
  /// watermark ([logoPath], bottom-right), and [lowerThirdText] (shown for
  /// the clip's first 3 seconds).
  Future<void> exportClip({
    required String sourcePath,
    required Duration start,
    required Duration end,
    required String outputPath,
    String? subtitlesPath,
    String? forceStyle,
    String? logoPath,
    String? lowerThirdText,
  }) async {
    var base = 'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920';
    if (subtitlesPath != null) {
      final style = forceStyle ??
          'Fontsize=20,PrimaryColour=&HFFFFFF&,OutlineColour=&H000000&,BorderStyle=1,Outline=2';
      base += ",subtitles='${_escapeFilterValue(subtitlesPath)}':force_style='$style'";
    }
    if (lowerThirdText != null) {
      base += ",drawtext=text='${_escapeFilterValue(lowerThirdText)}':fontcolor=white:fontsize=36:"
          "x=(w-text_w)/2:y=h-160:box=1:boxcolor=black@0.5:boxborderw=12:enable='between(t\\,0\\,3)'";
    }

    final args = <String>[
      '-y',
      '-ss', _seconds(start),
      '-to', _seconds(end),
      '-i', sourcePath,
    ];

    if (logoPath != null) {
      args.addAll(['-i', logoPath]);
      final filterComplex = '[0:v]$base[base];[1:v]scale=160:-1[logo];'
          '[base][logo]overlay=W-w-32:H-h-32[outv]';
      args.addAll(['-filter_complex', filterComplex, '-map', '[outv]', '-map', '0:a?']);
    } else {
      args.addAll(['-vf', base, '-map', '0:v', '-map', '0:a?']);
    }

    args.addAll(['-c:v', 'libx264', '-c:a', 'aac', outputPath]);

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw StateError('ffmpeg export failed (code $returnCode): $logs');
    }
  }

  /// Escapes a value embedded inside a single-quoted ffmpeg filter option
  /// (a `subtitles` path or `drawtext` string) — only single quotes need
  /// escaping here since the surrounding quotes already protect other
  /// special characters, and export always runs on Android (no
  /// drive-letter colons to worry about in paths).
  String _escapeFilterValue(String value) => value.replaceAll("'", "\\'");

  String _betweenClause(SilenceRange r) => 'between(t,${_seconds(r.start)},${_seconds(r.end)})';

  String _seconds(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);
}

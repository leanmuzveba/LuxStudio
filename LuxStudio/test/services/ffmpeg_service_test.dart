import 'package:flutter_test/flutter_test.dart';
import 'package:luxstudio/services/ffmpeg_service.dart';

void main() {
  group('parseSilenceLog', () {
    test('parses a single silence_start/silence_end pair', () {
      const log = '''
[silencedetect @ 0x7f1] silence_start: 1.234
[silencedetect @ 0x7f1] silence_end: 3.456 | silence_duration: 2.222
''';

      final ranges = parseSilenceLog(log);

      expect(ranges, hasLength(1));
      expect(ranges.single.start, const Duration(milliseconds: 1234));
      expect(ranges.single.end, const Duration(milliseconds: 3456));
    });

    test('parses multiple pairs in order', () {
      const log = '''
[silencedetect] silence_start: 0.5
[silencedetect] silence_end: 1.0 | silence_duration: 0.5
some unrelated ffmpeg log line
[silencedetect] silence_start: 10.0
[silencedetect] silence_end: 12.75 | silence_duration: 2.75
''';

      final ranges = parseSilenceLog(log);

      expect(ranges, hasLength(2));
      expect(ranges[0].start, const Duration(milliseconds: 500));
      expect(ranges[0].end, const Duration(milliseconds: 1000));
      expect(ranges[1].start, const Duration(seconds: 10));
      expect(ranges[1].end, const Duration(milliseconds: 12750));
    });

    test('ignores an unpaired silence_start with no matching end', () {
      const log = '''
[silencedetect] silence_start: 5.0
''';

      expect(parseSilenceLog(log), isEmpty);
    });

    test('returns an empty list for a log with no silence markers', () {
      const log = 'frame=  100 fps=30 q=-1.0 size=    512kB time=00:00:03.33';

      expect(parseSilenceLog(log), isEmpty);
    });

    test('returns an empty list for an empty log', () {
      expect(parseSilenceLog(''), isEmpty);
    });
  });
}

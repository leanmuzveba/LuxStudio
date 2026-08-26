import 'package:flutter_test/flutter_test.dart';
import 'package:luxstudio/services/gemini_service.dart';

void main() {
  group('decodeJsonArray', () {
    test('decodes a plain JSON array', () {
      final decoded = decodeJsonArray('[{"a": 1}, {"a": 2}]');
      expect(decoded, hasLength(2));
    });

    test('strips a markdown code fence Gemini adds despite being told not to', () {
      const raw = '```json\n[{"a": 1}]\n```';
      final decoded = decodeJsonArray(raw);
      expect(decoded, hasLength(1));
      expect((decoded.single as Map)['a'], 1);
    });

    test('strips a bare code fence with no language tag', () {
      const raw = '```\n[1, 2, 3]\n```';
      expect(decodeJsonArray(raw), [1, 2, 3]);
    });

    test('throws FormatException when the response is not a JSON array', () {
      expect(() => decodeJsonArray('{"not": "an array"}'), throwsFormatException);
    });
  });

  group('transcriptSegmentFromJson', () {
    test('converts fractional seconds to milliseconds and trims text', () {
      final segment = transcriptSegmentFromJson({
        'startSeconds': 1.5,
        'endSeconds': 3.25,
        'text': '  hello there  ',
      }, 7);

      expect(segment.id, 't7');
      expect(segment.start, const Duration(milliseconds: 1500));
      expect(segment.end, const Duration(milliseconds: 3250));
      expect(segment.text, 'hello there');
    });
  });

  group('aiClipFromJson', () {
    test('maps fields and rounds seconds', () {
      final clip = aiClipFromJson({
        'title': '  Great moment  ',
        'startSeconds': 10,
        'endSeconds': 45,
        'viralScore': 87,
        'reason': '  quotable line  ',
      }, 'clip-id');

      expect(clip.id, 'clip-id');
      expect(clip.title, 'Great moment');
      expect(clip.start, const Duration(seconds: 10));
      expect(clip.end, const Duration(seconds: 45));
      expect(clip.viralScore, 87);
      expect(clip.reason, 'quotable line');
      expect(clip.category, '');
    });

    test('maps category when present', () {
      final clip = aiClipFromJson({
        'title': 't',
        'startSeconds': 0,
        'endSeconds': 1,
        'viralScore': 50,
        'reason': 'r',
        'category': ' Strong Hook ',
      }, 'id');

      expect(clip.category, 'Strong Hook');
    });

    test('clamps an out-of-range viralScore into 0-100', () {
      final tooHigh = aiClipFromJson({
        'title': 't',
        'startSeconds': 0,
        'endSeconds': 1,
        'viralScore': 150,
        'reason': 'r',
      }, 'id');
      expect(tooHigh.viralScore, 100);

      final tooLow = aiClipFromJson({
        'title': 't',
        'startSeconds': 0,
        'endSeconds': 1,
        'viralScore': -20,
        'reason': 'r',
      }, 'id');
      expect(tooLow.viralScore, 0);
    });
  });

  group('socialCopyFromJson', () {
    test('maps fields, trims text, and strips leading # from hashtags', () {
      final copy = socialCopyFromJson({
        'title': '  Big moment  ',
        'summary': '  a summary  ',
        'description': '  a longer description  ',
        'hashtags': ['#faith', 'hope', '#love'],
      });

      expect(copy.title, 'Big moment');
      expect(copy.summary, 'a summary');
      expect(copy.description, 'a longer description');
      expect(copy.hashtags, ['faith', 'hope', 'love']);
    });

    test('defaults missing fields to empty', () {
      final copy = socialCopyFromJson({});

      expect(copy.title, '');
      expect(copy.summary, '');
      expect(copy.description, '');
      expect(copy.hashtags, isEmpty);
    });
  });
}

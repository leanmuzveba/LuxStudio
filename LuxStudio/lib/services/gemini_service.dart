import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_clip.dart';
import '../models/social_copy.dart';
import '../models/transcript_segment.dart';
import 'secure_settings.dart';

/// Gemini is prompted for raw JSON but sometimes wraps it in a markdown
/// code fence anyway — strip that defensively before decoding. Pure and
/// side-effect-free so it's directly unit testable.
List<dynamic> decodeJsonArray(String raw) {
  var cleaned = raw.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
    final fenceEnd = cleaned.lastIndexOf('```');
    if (fenceEnd != -1) cleaned = cleaned.substring(0, fenceEnd);
  }
  final decoded = jsonDecode(cleaned.trim());
  if (decoded is! List) {
    throw FormatException('Expected a JSON array from Gemini, got: $decoded');
  }
  return decoded;
}

/// Maps one `{startSeconds, endSeconds, text}` entry from
/// [GeminiService.transcribe]'s response into a [TranscriptSegment].
TranscriptSegment transcriptSegmentFromJson(Map<String, dynamic> map, int index) {
  return TranscriptSegment(
    id: 't$index',
    start: Duration(milliseconds: ((map['startSeconds'] as num) * 1000).round()),
    end: Duration(milliseconds: ((map['endSeconds'] as num) * 1000).round()),
    text: (map['text'] as String).trim(),
  );
}

/// Maps one `{title, startSeconds, endSeconds, viralScore, reason,
/// category}` entry from [GeminiService.suggestClips]'s response into an
/// [AiClip].
AiClip aiClipFromJson(Map<String, dynamic> map, String id) {
  return AiClip(
    id: id,
    title: (map['title'] as String).trim(),
    start: Duration(seconds: (map['startSeconds'] as num).round()),
    end: Duration(seconds: (map['endSeconds'] as num).round()),
    viralScore: (map['viralScore'] as num).round().clamp(0, 100),
    reason: (map['reason'] as String).trim(),
    category: ((map['category'] as String?) ?? '').trim(),
  );
}

/// Maps a `{title, summary, description, hashtags}` object from
/// [GeminiService.generateSocialCopy]'s response into a [SocialCopy].
SocialCopy socialCopyFromJson(Map<String, dynamic> map) {
  return SocialCopy(
    title: ((map['title'] as String?) ?? '').trim(),
    summary: ((map['summary'] as String?) ?? '').trim(),
    description: ((map['description'] as String?) ?? '').trim(),
    hashtags: ((map['hashtags'] as List?) ?? const [])
        .map((e) => e.toString().trim().replaceFirst(RegExp(r'^#'), ''))
        .where((tag) => tag.isNotEmpty)
        .toList(),
  );
}

/// Wraps the Gemini API for the AI work LuxStudio needs directly from the
/// app (no backend): transcription, clip suggestions, and social copy
/// generation.
///
/// The user's own API key (entered in Settings, never hardcoded) is read
/// fresh for each call via [SecureSettings].
///
/// Note: audio is sent inline (base64) rather than through Gemini's File
/// API, which this package version doesn't expose a upload helper for.
/// That keeps requests simple but caps how long a recording can be
/// transcribed in one call — very long sermons may need to be split in a
/// future revision.
class GeminiService {
  GeminiService({SecureSettings? secureSettings})
      : _secureSettings = secureSettings ?? SecureSettings();

  final SecureSettings _secureSettings;

  static const _modelName = 'gemini-2.5-flash';

  Future<GenerativeModel> _model({String? responseMimeType}) async {
    final apiKey = await _secureSettings.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('No Gemini API key set — add one in Settings first.');
    }
    return GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: responseMimeType),
    );
  }

  /// Transcribes [audioBytes] into timestamped [TranscriptSegment]s.
  Future<List<TranscriptSegment>> transcribe(Uint8List audioBytes, String mimeType) async {
    final model = await _model(responseMimeType: 'application/json');
    const prompt = '''
Transcribe the spoken audio. Return ONLY a JSON array (no markdown, no
commentary) covering the entire audio in order, back-to-back, with no
gaps or overlaps. Each element must be exactly:
{"startSeconds": number, "endSeconds": number, "text": string}
One element per spoken sentence or phrase. If a stretch of audio has no
speech, skip it (don't emit an element with empty text).
''';

    final response = await model.generateContent([
      Content.multi([TextPart(prompt), DataPart(mimeType, audioBytes)]),
    ]);

    final decoded = decodeJsonArray(_extractText(response));
    var index = 0;
    return decoded.map((entry) {
      index++;
      return transcriptSegmentFromJson(entry as Map<String, dynamic>, index);
    }).toList();
  }

  /// Asks Gemini to find complete, engaging short-form clip candidates in
  /// [transcript] (silent gaps and lines marked for cut are excluded from
  /// what's sent, matching what the user has actually kept).
  Future<List<AiClip>> suggestClips(List<TranscriptSegment> transcript) async {
    final model = await _model(responseMimeType: 'application/json');
    final lines = transcript
        .where((s) => !s.isSilence && !s.isMarkedForCut && s.text.trim().isNotEmpty)
        .map((s) => '[${s.start.inSeconds}s-${s.end.inSeconds}s] ${s.text}')
        .join('\n');

    final prompt = '''
Here is a timestamped transcript of a spoken recording:

$lines

Identify 3 to 6 short-form clip candidates suitable for social media
(15-90 seconds each) — look for strong openings, complete ideas, and
memorable or quotable moments. Clips should not overlap. Start/end times
must be seconds taken from the transcript timestamps above (start of a
line's bracket to end of a line's bracket).

Return ONLY a JSON array (no markdown, no commentary) where each element
is exactly:
{"title": string, "startSeconds": number, "endSeconds": number, "viralScore": integer 0-100, "reason": string, "category": string}

"reason" is one short sentence on why this moment works as a standalone
clip. "category" is a short 2-3 word tag naming the type of moment, e.g.
"Strong Hook", "Complete Idea", "Memorable Quote", or "Hot Take". Order
the array by viralScore, highest first.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final decoded = decodeJsonArray(_extractText(response));
    const uuid = Uuid();
    return decoded
        .map((entry) => aiClipFromJson(entry as Map<String, dynamic>, uuid.v4()))
        .toList();
  }

  /// Writes ready-to-post social copy — a title, a one-line summary, a
  /// longer description, and hashtags, each independently usable — for
  /// [clip], grounded in the portion of [transcript] the clip actually
  /// covers.
  Future<SocialCopy> generateSocialCopy({
    required List<TranscriptSegment> transcript,
    required AiClip clip,
  }) async {
    final model = await _model(responseMimeType: 'application/json');
    final clipText = transcript
        .where((s) =>
            !s.isSilence && s.text.trim().isNotEmpty && s.end > clip.start && s.start < clip.end)
        .map((s) => s.text)
        .join(' ');

    final prompt = '''
This is the transcript of a short clip titled "${clip.title}":

$clipText

Write ready-to-post social media copy for this clip:
- "title": a short, punchy hook (under 60 characters)
- "summary": one-line description of what the clip is about
- "description": a longer 2-3 sentence caption suitable for a post body
- "hashtags": 3-6 relevant hashtags, without the # symbol

Return ONLY a JSON object (no markdown, no commentary) exactly:
{"title": string, "summary": string, "description": string, "hashtags": string[]}
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final decoded = _decodeJsonObject(_extractText(response));
    return socialCopyFromJson(decoded);
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      final fenceEnd = cleaned.lastIndexOf('```');
      if (fenceEnd != -1) cleaned = cleaned.substring(0, fenceEnd);
    }
    final decoded = jsonDecode(cleaned.trim());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected a JSON object from Gemini, got: $decoded');
    }
    return decoded;
  }

  String _extractText(GenerateContentResponse response) {
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return text;
  }
}

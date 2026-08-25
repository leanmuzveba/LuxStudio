import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/transcript_segment.dart';
import 'secure_settings.dart';

/// Wraps the Gemini API for the AI work LuxStudio needs directly from the
/// app (no backend): transcription now, and — in later phases — clip
/// suggestions and social copy generation.
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

    final decoded = _decodeJsonArray(_extractText(response));
    var index = 0;
    return decoded.map((entry) {
      final map = entry as Map<String, dynamic>;
      index++;
      return TranscriptSegment(
        id: 't$index',
        start: Duration(milliseconds: ((map['startSeconds'] as num) * 1000).round()),
        end: Duration(milliseconds: ((map['endSeconds'] as num) * 1000).round()),
        text: (map['text'] as String).trim(),
      );
    }).toList();
  }

  String _extractText(GenerateContentResponse response) {
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return text;
  }

  /// Gemini is prompted for raw JSON but sometimes wraps it in a markdown
  /// code fence anyway — strip that defensively before decoding.
  List<dynamic> _decodeJsonArray(String raw) {
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
}

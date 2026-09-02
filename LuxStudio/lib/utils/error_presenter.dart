import 'package:flutter/foundation.dart';

class _ErrorCode {
  final int code;
  final String label;
  const _ErrorCode(this.code, this.label);
}

const _rules = <(String needle, _ErrorCode code)>[
  ('failed host lookup', _ErrorCode(1, 'CONNECTION FAILED')),
  ('socketexception', _ErrorCode(1, 'CONNECTION FAILED')),
  ('connection refused', _ErrorCode(1, 'CONNECTION FAILED')),
  ('timeoutexception', _ErrorCode(2, 'REQUEST TIMED OUT')),
  ('silence', _ErrorCode(101, 'SILENCE REMOVAL FAILED')),
  ('extract_audio', _ErrorCode(102, 'AUDIO EXTRACTION FAILED')),
  ('transcri', _ErrorCode(103, 'TRANSCRIPTION FAILED')),
  ('clip', _ErrorCode(104, 'CLIP DETECTION FAILED')),
  ('caption', _ErrorCode(105, 'CAPTIONING FAILED')),
  ('gemini', _ErrorCode(301, 'AI SERVICE FAILED')),
  ('export', _ErrorCode(201, 'EXPORT FAILED')),
  ('ffmpeg', _ErrorCode(199, 'PROCESSING FAILED')),
];

/// Turns a raw backend/exception string (often a full ffmpeg stderr dump
/// or Dart stack trace) into a short, user-safe label + numeric code, e.g.
/// "SILENCE REMOVAL FAILED — Error 101. Check the log for details." The
/// full raw text still goes to the debug console via [debugPrint] — never
/// shown as an on-screen paragraph, since backend errors can be arbitrarily
/// long and technical.
String friendlyError(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return 'UNEXPECTED ERROR — Error 900. Check the log for details.';
  }
  debugPrint('LuxStudio error detail: $raw');
  final lower = raw.toLowerCase();
  for (final (needle, code) in _rules) {
    if (lower.contains(needle)) {
      return '${code.label} — Error ${code.code}. Check the log for details.';
    }
  }
  return 'UNEXPECTED ERROR — Error 900. Check the log for details.';
}

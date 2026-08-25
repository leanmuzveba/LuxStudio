/// A single line of the auto-generated transcript, editable inline in the
/// video editor. [isSilence] marks a gap the silence-removal pass cut out
/// (rendered as a collapsed divider rather than a text line).
class TranscriptSegment {
  final String id;
  final Duration start;
  final Duration end;
  String text;
  bool isSilence;
  bool isMarkedForCut;

  TranscriptSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
    this.isSilence = false,
    this.isMarkedForCut = false,
  });

  Duration get duration => end - start;

  String get timeLabel => '${_fmt(start)} – ${_fmt(end)}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'text': text,
        'isSilence': isSilence,
        'isMarkedForCut': isMarkedForCut,
      };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) => TranscriptSegment(
        id: json['id'] as String,
        start: Duration(milliseconds: json['startMs'] as int),
        end: Duration(milliseconds: json['endMs'] as int),
        text: json['text'] as String,
        isSilence: json['isSilence'] as bool? ?? false,
        isMarkedForCut: json['isMarkedForCut'] as bool? ?? false,
      );

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

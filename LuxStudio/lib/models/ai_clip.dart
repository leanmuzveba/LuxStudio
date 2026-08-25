/// An AI-surfaced short-form candidate cut from the full sermon, ranked by
/// a predicted engagement score.
class AiClip {
  final String id;
  final String title;
  final Duration start;
  final Duration end;
  final int viralScore; // 0–100
  final String reason;

  const AiClip({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.viralScore,
    required this.reason,
  });

  Duration get duration => end - start;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'viralScore': viralScore,
        'reason': reason,
      };

  factory AiClip.fromJson(Map<String, dynamic> json) => AiClip(
        id: json['id'] as String,
        title: json['title'] as String,
        start: Duration(milliseconds: json['startMs'] as int),
        end: Duration(milliseconds: json['endMs'] as int),
        viralScore: json['viralScore'] as int,
        reason: json['reason'] as String,
      );

  String get timeRangeLabel => '${_fmt(start)} – ${_fmt(end)}';

  String get durationLabel {
    final s = duration.inSeconds;
    return '${s}s';
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

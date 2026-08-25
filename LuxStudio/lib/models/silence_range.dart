/// A silent (or near-silent) stretch detected in the audio track.
///
/// [accepted] tracks the user's review decision — detection finds
/// candidates, but only accepted ranges are actually cut when the user
/// applies silence removal.
class SilenceRange {
  final Duration start;
  final Duration end;
  bool accepted;

  SilenceRange({required this.start, required this.end, this.accepted = true});

  Duration get duration => end - start;

  Map<String, dynamic> toJson() => {
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'accepted': accepted,
      };

  factory SilenceRange.fromJson(Map<String, dynamic> json) => SilenceRange(
        start: Duration(milliseconds: json['startMs'] as int),
        end: Duration(milliseconds: json['endMs'] as int),
        accepted: json['accepted'] as bool? ?? true,
      );
}

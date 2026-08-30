/// Ready-to-post social copy for a clip, as structured fields (replacing
/// the earlier "pick one of 3 caption strings" flow) — each field is
/// independently editable and copyable on the Social screen.
class SocialCopy {
  final String title;
  final String summary;
  final String description;
  final List<String> hashtags;

  const SocialCopy({
    required this.title,
    required this.summary,
    required this.description,
    required this.hashtags,
  });

  static const empty = SocialCopy(title: '', summary: '', description: '', hashtags: []);

  /// The single combined caption blob the Share screen shows — the mockup
  /// (`ui_kit/share/index.html`) has one "AI Generated Captions" text
  /// block, not 4 separate fields. Keeps the structured fields as the
  /// source of truth (still independently useful) and just composes a
  /// display string from them: the description (falling back to summary
  /// if empty) followed by hashtags.
  String get displayBlob {
    final body = description.trim().isNotEmpty ? description.trim() : summary.trim();
    final tags = hashtags.map((h) => '#$h').join(' ');
    if (body.isEmpty) return tags;
    if (tags.isEmpty) return body;
    return '$body $tags';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'description': description,
        'hashtags': hashtags,
      };

  factory SocialCopy.fromJson(Map<String, dynamic> json) => SocialCopy(
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        description: json['description'] as String? ?? '',
        hashtags: (json['hashtags'] as List?)?.cast<String>() ?? const [],
      );
}

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

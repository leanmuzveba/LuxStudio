/// A branding toggle applied at export time (watermark, lower third, etc).
class BrandingPreset {
  final String id;
  final String label;
  final String description;
  bool enabled;

  BrandingPreset({
    required this.id,
    required this.label,
    required this.description,
    this.enabled = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'description': description,
        'enabled': enabled,
      };

  factory BrandingPreset.fromJson(Map<String, dynamic> json) => BrandingPreset(
        id: json['id'] as String,
        label: json['label'] as String,
        description: json['description'] as String,
        enabled: json['enabled'] as bool,
      );
}

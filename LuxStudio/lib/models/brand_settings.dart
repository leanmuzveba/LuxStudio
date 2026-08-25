/// Reusable branding details — a logo and organisation name — applied
/// across exports when branding is enabled. Global to the app (not tied
/// to one project), so they carry over to every new sermon imported.
class BrandSettings {
  final String? logoPath;
  final String organizationName;

  const BrandSettings({this.logoPath, this.organizationName = ''});

  static const empty = BrandSettings();

  Map<String, dynamic> toJson() => {
        'logoPath': logoPath,
        'organizationName': organizationName,
      };

  factory BrandSettings.fromJson(Map<String, dynamic> json) => BrandSettings(
        logoPath: json['logoPath'] as String?,
        organizationName: json['organizationName'] as String? ?? '',
      );
}

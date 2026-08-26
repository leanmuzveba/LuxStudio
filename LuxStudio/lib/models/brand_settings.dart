/// A named brand accent color the user can pick for watermark/overlay tint.
enum BrandColorPreset { gold, amber, bronze, tan, slate, ink }

/// Which corner of the frame the logo watermark is placed in.
enum WatermarkCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Reusable branding details — a logo and organisation name — applied
/// across exports when branding is enabled. Global to the app (not tied
/// to one project), so they carry over to every new sermon imported.
class BrandSettings {
  final String? logoPath;
  final String organizationName;
  final BrandColorPreset color;
  final WatermarkCorner watermarkCorner;

  const BrandSettings({
    this.logoPath,
    this.organizationName = '',
    this.color = BrandColorPreset.gold,
    this.watermarkCorner = WatermarkCorner.bottomRight,
  });

  static const empty = BrandSettings();

  Map<String, dynamic> toJson() => {
        'logoPath': logoPath,
        'organizationName': organizationName,
        'color': color.name,
        'watermarkCorner': watermarkCorner.name,
      };

  factory BrandSettings.fromJson(Map<String, dynamic> json) => BrandSettings(
        logoPath: json['logoPath'] as String?,
        organizationName: json['organizationName'] as String? ?? '',
        color: BrandColorPreset.values.byName(json['color'] as String? ?? 'gold'),
        watermarkCorner:
            WatermarkCorner.values.byName(json['watermarkCorner'] as String? ?? 'bottomRight'),
      );
}

/// A named brand accent color the user can pick for watermark/overlay tint.
enum BrandColorPreset { gold, amber, bronze, tan, slate, ink }

/// Which corner of the frame the logo watermark is placed in.
enum WatermarkCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Reusable branding details — a logo and organisation name — applied
/// across exports when branding is enabled. Global to the app (not tied
/// to one project), so they carry over to every new sermon imported.
///
/// [logoUrl] is a path relative to the backend's base URL (e.g.
/// `/brand/logo`, see backend/app/routers/brand.py) rather than a local
/// file — the logo lives on the backend now, not in an app sandbox.
class BrandSettings {
  final String? logoUrl;
  final String organizationName;
  final BrandColorPreset color;
  final WatermarkCorner watermarkCorner;

  const BrandSettings({
    this.logoUrl,
    this.organizationName = '',
    this.color = BrandColorPreset.gold,
    this.watermarkCorner = WatermarkCorner.bottomRight,
  });

  static const empty = BrandSettings();

  Map<String, dynamic> toJson() => {
        'logoUrl': logoUrl,
        'organizationName': organizationName,
        'color': color.name,
        'watermarkCorner': watermarkCorner.name,
      };

  factory BrandSettings.fromJson(Map<String, dynamic> json) => BrandSettings(
        logoUrl: json['logoUrl'] as String?,
        organizationName: json['organizationName'] as String? ?? '',
        color: BrandColorPreset.values.byName(json['color'] as String? ?? 'gold'),
        watermarkCorner:
            WatermarkCorner.values.byName(json['watermarkCorner'] as String? ?? 'bottomRight'),
      );
}

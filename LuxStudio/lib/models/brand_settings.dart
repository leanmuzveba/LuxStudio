import 'caption_style.dart';

/// A named brand accent color the user can pick for watermark/overlay tint.
enum BrandColorPreset { gold, amber, bronze, tan, slate, ink }

/// Which corner of the frame the logo watermark is placed in.
enum WatermarkCorner { topLeft, topRight, bottomLeft, bottomRight }

/// One named recurring service time (e.g. "Sunday Service", "9:00 AM –
/// 12:00 PM") shown on the Settings screen's Contact & Service Times card.
class ServiceTime {
  final String label;
  final String time;

  const ServiceTime({required this.label, required this.time});

  Map<String, dynamic> toJson() => {'label': label, 'time': time};

  factory ServiceTime.fromJson(Map<String, dynamic> json) => ServiceTime(
        label: json['label'] as String? ?? '',
        time: json['time'] as String? ?? '',
      );
}

/// Reusable branding + church-profile details — applied across exports
/// (logo/color/watermark) and surfaced as social-copy/export defaults
/// (address, service times, default caption template, default hashtags,
/// giving info). Global to the app (not tied to one project), so they
/// carry over to every new sermon imported.
///
/// [logoUrl] is a path relative to the backend's base URL (e.g.
/// `/brand/logo`, see backend/app/routers/brand.py) rather than a local
/// file — the logo lives on the backend now, not in an app sandbox.
class BrandSettings {
  final String? logoUrl;
  final String organizationName;
  final BrandColorPreset color;
  final WatermarkCorner watermarkCorner;
  final String address;
  final List<ServiceTime> serviceTimes;
  final CaptionTemplate defaultCaptionTemplate;
  final List<String> defaultHashtags;

  /// Off by default — giving details are only ever appended to generated
  /// posts when this is explicitly enabled (PRD data-safety requirement).
  final bool givingEnabled;
  final String givingAccountText;

  const BrandSettings({
    this.logoUrl,
    this.organizationName = '',
    this.color = BrandColorPreset.gold,
    this.watermarkCorner = WatermarkCorner.bottomRight,
    this.address = '',
    this.serviceTimes = const [],
    this.defaultCaptionTemplate = CaptionTemplate.boldPop,
    this.defaultHashtags = const [],
    this.givingEnabled = false,
    this.givingAccountText = '',
  });

  /// The out-of-the-box defaults for this church-branded build (from
  /// CLAUDE.md's "Default church config", PRD §8) — pre-filled rather
  /// than blank, matching what `ui_kit/settings/index.html` shows as its
  /// example content. Giving stays off until the user explicitly enables
  /// it, even though the account number is already known.
  static const seeded = BrandSettings(
    organizationName: 'Higherlife Commission',
    address: '65 11th Road, Kew, Johannesburg, Gauteng, South Africa, 2090',
    serviceTimes: [
      ServiceTime(label: 'Sunday Service', time: '9:00 AM – 12:00 PM'),
      ServiceTime(label: 'Thursday Service', time: '6:00 PM – 8:00 PM'),
    ],
    defaultHashtags: ['wordsofwisdom', 'lifeinthespirit', 'lifeinthespiritseminar'],
    givingEnabled: false,
    givingAccountText: 'FNB Account 62777808208',
  );

  Map<String, dynamic> toJson() => {
        'logoUrl': logoUrl,
        'organizationName': organizationName,
        'color': color.name,
        'watermarkCorner': watermarkCorner.name,
        'address': address,
        'serviceTimes': serviceTimes.map((s) => s.toJson()).toList(),
        'defaultCaptionTemplate': defaultCaptionTemplate.name,
        'defaultHashtags': defaultHashtags,
        'givingEnabled': givingEnabled,
        'givingAccountText': givingAccountText,
      };

  factory BrandSettings.fromJson(Map<String, dynamic> json) => BrandSettings(
        logoUrl: json['logoUrl'] as String?,
        organizationName: json['organizationName'] as String? ?? '',
        color: BrandColorPreset.values.byName(json['color'] as String? ?? 'gold'),
        watermarkCorner:
            WatermarkCorner.values.byName(json['watermarkCorner'] as String? ?? 'bottomRight'),
        address: json['address'] as String? ?? '',
        serviceTimes: (json['serviceTimes'] as List?)
                ?.map((e) => ServiceTime.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        defaultCaptionTemplate:
            CaptionTemplate.values.byName(json['defaultCaptionTemplate'] as String? ?? 'boldPop'),
        defaultHashtags: (json['defaultHashtags'] as List?)?.cast<String>() ?? const [],
        givingEnabled: json['givingEnabled'] as bool? ?? false,
        givingAccountText: json['givingAccountText'] as String? ?? '',
      );

  BrandSettings copyWith({
    String? logoUrl,
    String? organizationName,
    BrandColorPreset? color,
    WatermarkCorner? watermarkCorner,
    String? address,
    List<ServiceTime>? serviceTimes,
    CaptionTemplate? defaultCaptionTemplate,
    List<String>? defaultHashtags,
    bool? givingEnabled,
    String? givingAccountText,
  }) =>
      BrandSettings(
        logoUrl: logoUrl ?? this.logoUrl,
        organizationName: organizationName ?? this.organizationName,
        color: color ?? this.color,
        watermarkCorner: watermarkCorner ?? this.watermarkCorner,
        address: address ?? this.address,
        serviceTimes: serviceTimes ?? this.serviceTimes,
        defaultCaptionTemplate: defaultCaptionTemplate ?? this.defaultCaptionTemplate,
        defaultHashtags: defaultHashtags ?? this.defaultHashtags,
        givingEnabled: givingEnabled ?? this.givingEnabled,
        givingAccountText: givingAccountText ?? this.givingAccountText,
      );
}

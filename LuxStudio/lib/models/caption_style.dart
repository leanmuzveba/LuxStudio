/// A named burned-in caption look the user can pick on the Captions
/// screen — mirrors the "Bold Pop / Minimal / Karaoke" presets in the
/// design mockup.
enum CaptionTemplate { boldPop, minimal, karaoke }

/// How burned-in captions are styled at export — feeds
/// [FfmpegService.exportClip]'s subtitle `force_style` string via
/// [assForceStyle].
class CaptionStyle {
  final CaptionTemplate template;
  final String fontFamily;
  final double fontSize;

  /// ARGB color ints (e.g. `0xFFFFFFFF`) — Flutter's native color format,
  /// converted to ffmpeg's ASS `&HAABBGGRR&` format only at export time.
  final int textColor;
  final int highlightColor;

  const CaptionStyle({
    this.template = CaptionTemplate.boldPop,
    this.fontFamily = 'Montserrat',
    this.fontSize = 20,
    this.textColor = 0xFFFFFFFF,
    this.highlightColor = 0xFFF4B315,
  });

  static const defaultStyle = CaptionStyle();

  CaptionStyle copyWith({
    CaptionTemplate? template,
    String? fontFamily,
    double? fontSize,
    int? textColor,
    int? highlightColor,
  }) =>
      CaptionStyle(
        template: template ?? this.template,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        textColor: textColor ?? this.textColor,
        highlightColor: highlightColor ?? this.highlightColor,
      );

  Map<String, dynamic> toJson() => {
        'template': template.name,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'textColor': textColor,
        'highlightColor': highlightColor,
      };

  factory CaptionStyle.fromJson(Map<String, dynamic> json) => CaptionStyle(
        template: CaptionTemplate.values.byName(json['template'] as String? ?? 'boldPop'),
        fontFamily: json['fontFamily'] as String? ?? 'Montserrat',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 20,
        textColor: json['textColor'] as int? ?? 0xFFFFFFFF,
        highlightColor: json['highlightColor'] as int? ?? 0xFFF4B315,
      );

  /// The ffmpeg `subtitles` filter's `force_style` value for this style.
  /// ASS colors are `&HAABBGGRR&` — alpha + blue/green/red, the reverse
  /// byte order of Flutter's ARGB ints.
  String get assForceStyle {
    final bold = template == CaptionTemplate.boldPop ? '1' : '0';
    return 'FontName=$fontFamily,Fontsize=${fontSize.round()},'
        'PrimaryColour=${_toAssColor(textColor)},'
        'OutlineColour=${_toAssColor(0xFF000000)},'
        'Bold=$bold,BorderStyle=1,Outline=2';
  }

  static String _toAssColor(int argb) {
    String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return '&H${hex(b)}${hex(g)}${hex(r)}&';
  }
}

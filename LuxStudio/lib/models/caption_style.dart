/// A named burned-in caption look — the "Bold Word / Clean Line /
/// Highlight" swatches on the Settings screen's Default Caption Template
/// card pick this per church, project-level styling is a future revisit.
enum CaptionTemplate { boldPop, minimal, karaoke }

/// Where burned-in captions sit vertically — real standalone control added
/// in V2 Phase 29 (Decision #4), not just a decorative option: drives both
/// the live preview and the ffmpeg ASS `Alignment` at export.
enum SubtitlePosition { top, middle, bottom }

/// How burned-in captions are styled at export — feeds the backend's
/// `export_clip`'s subtitle `force_style` string via [assForceStyle] (see
/// `backend/app/services/ffmpeg_client.py`), and (for [timingOffsetMs]) the
/// SRT timestamps themselves via [AppState._buildSrt].
class CaptionStyle {
  final CaptionTemplate template;
  final String fontFamily;
  final double fontSize;
  final bool italic;
  final SubtitlePosition position;

  /// Shifts every caption's start/end by this many milliseconds at export
  /// (positive = later, negative = earlier) — a real lip-sync correction,
  /// not cosmetic. See `lib/screens/subtitles_desktop_screen.dart`.
  final int timingOffsetMs;

  /// ARGB color ints (e.g. `0xFFFFFFFF`) — Flutter's native color format,
  /// converted to ffmpeg's ASS `&HAABBGGRR&` format only at export time.
  final int textColor;
  final int highlightColor;

  const CaptionStyle({
    this.template = CaptionTemplate.boldPop,
    this.fontFamily = 'Montserrat',
    this.fontSize = 20,
    this.italic = false,
    this.position = SubtitlePosition.bottom,
    this.timingOffsetMs = 0,
    this.textColor = 0xFFFFFFFF,
    this.highlightColor = 0xFFF4B315,
  });

  static const defaultStyle = CaptionStyle();

  CaptionStyle copyWith({
    CaptionTemplate? template,
    String? fontFamily,
    double? fontSize,
    bool? italic,
    SubtitlePosition? position,
    int? timingOffsetMs,
    int? textColor,
    int? highlightColor,
  }) =>
      CaptionStyle(
        template: template ?? this.template,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        italic: italic ?? this.italic,
        position: position ?? this.position,
        timingOffsetMs: timingOffsetMs ?? this.timingOffsetMs,
        textColor: textColor ?? this.textColor,
        highlightColor: highlightColor ?? this.highlightColor,
      );

  Map<String, dynamic> toJson() => {
        'template': template.name,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'italic': italic,
        'position': position.name,
        'timingOffsetMs': timingOffsetMs,
        'textColor': textColor,
        'highlightColor': highlightColor,
      };

  factory CaptionStyle.fromJson(Map<String, dynamic> json) => CaptionStyle(
        template: CaptionTemplate.values.byName(json['template'] as String? ?? 'boldPop'),
        fontFamily: json['fontFamily'] as String? ?? 'Montserrat',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 20,
        italic: json['italic'] as bool? ?? false,
        position: SubtitlePosition.values.byName(json['position'] as String? ?? 'bottom'),
        timingOffsetMs: (json['timingOffsetMs'] as num?)?.toInt() ?? 0,
        textColor: json['textColor'] as int? ?? 0xFFFFFFFF,
        highlightColor: json['highlightColor'] as int? ?? 0xFFF4B315,
      );

  /// The ffmpeg `subtitles` filter's `force_style` value for this style.
  /// ASS colors are `&HAABBGGRR&` — alpha + blue/green/red, the reverse
  /// byte order of Flutter's ARGB ints. ASS `Alignment` uses numpad
  /// layout (2=bottom-center, 5=middle-center, 8=top-center).
  String get assForceStyle {
    final bold = template == CaptionTemplate.boldPop ? '1' : '0';
    final italicFlag = italic ? '1' : '0';
    final alignment = switch (position) {
      SubtitlePosition.top => 8,
      SubtitlePosition.middle => 5,
      SubtitlePosition.bottom => 2,
    };
    return 'FontName=$fontFamily,Fontsize=${fontSize.round()},'
        'PrimaryColour=${_toAssColor(textColor)},'
        'OutlineColour=${_toAssColor(0xFF000000)},'
        'Bold=$bold,Italic=$italicFlag,BorderStyle=1,Outline=2,Alignment=$alignment';
  }

  static String _toAssColor(int argb) {
    String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return '&H${hex(b)}${hex(g)}${hex(r)}&';
  }
}

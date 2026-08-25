import 'package:flutter/foundation.dart';

import '../models/ai_clip.dart';
import '../models/export_destination.dart';
import '../models/processing_step.dart';
import '../models/transcript_segment.dart';
import '../models/video_project.dart';

/// App-wide state for the LuxStudio flow, shared across the four screens
/// via a single [ChangeNotifier] (see main.dart for how it's provided).
///
/// This intentionally avoids a state-management package — the flow is
/// linear and small enough that a plain ChangeNotifier plus
/// [AnimatedBuilder]/[ListenableBuilder] keeps the example dependency-free.
class AppState extends ChangeNotifier {
  VideoProject? project;

  /// Which pipeline stage the import screen is currently animating.
  int processingStageIndex = 0;
  bool processingComplete = false;

  final List<TranscriptSegment> transcript = [];
  final List<AiClip> suggestedClips = [];

  /// Currently active bottom tool on the editor screen.
  EditorTool activeTool = EditorTool.captions;

  /// The clip the user chose to edit & export.
  AiClip? selectedClip;

  final Set<ExportPlatform> selectedDestinations = {ExportPlatform.reels};
  int selectedCaptionIndex = 0;
  final List<BrandingPreset> brandingPresets = [
    BrandingPreset(
      id: 'watermark',
      label: 'Logo watermark',
      description: 'Small church logo, bottom-right corner.',
      enabled: true,
    ),
    BrandingPreset(
      id: 'lower_third',
      label: 'Lower third',
      description: 'Speaker name & sermon title on first 3s.',
      enabled: true,
    ),
    BrandingPreset(
      id: 'color_grade',
      label: 'Signature color grade',
      description: 'Warm, high-contrast look applied automatically.',
      enabled: false,
    ),
  ];

  final List<String> generatedCaptions = const [
    "You weren't made to carry this alone. 🙏 Full message linked in bio.",
    "This 45 seconds might change how you see this week. #faith #sermon",
    "Watch till the end — the last line hits different.",
  ];

  void startImport(VideoProject newProject) {
    project = newProject;
    processingStageIndex = 0;
    processingComplete = false;
    notifyListeners();
  }

  void advanceProcessingStage() {
    if (processingStageIndex < ProcessingStep.pipeline.length - 1) {
      processingStageIndex++;
    } else {
      processingComplete = true;
      _seedTranscriptAndClips();
    }
    notifyListeners();
  }

  void setActiveTool(EditorTool tool) {
    activeTool = tool;
    notifyListeners();
  }

  void updateTranscriptText(String segmentId, String newText) {
    final segment = transcript.firstWhere((s) => s.id == segmentId);
    segment.text = newText;
    notifyListeners();
  }

  void toggleMarkForCut(String segmentId) {
    final segment = transcript.firstWhere((s) => s.id == segmentId);
    segment.isMarkedForCut = !segment.isMarkedForCut;
    notifyListeners();
  }

  void chooseClip(AiClip clip) {
    selectedClip = clip;
    selectedDestinations
      ..clear()
      ..add(ExportPlatform.reels);
    selectedCaptionIndex = 0;
    notifyListeners();
  }

  void toggleDestination(ExportPlatform platform) {
    if (selectedDestinations.contains(platform)) {
      if (selectedDestinations.length > 1) {
        selectedDestinations.remove(platform);
      }
    } else {
      selectedDestinations.add(platform);
    }
    notifyListeners();
  }

  void selectCaption(int index) {
    selectedCaptionIndex = index;
    notifyListeners();
  }

  void toggleBranding(String id) {
    final preset = brandingPresets.firstWhere((p) => p.id == id);
    preset.enabled = !preset.enabled;
    notifyListeners();
  }

  void _seedTranscriptAndClips() {
    transcript
      ..clear()
      ..addAll(_mockTranscript());
    suggestedClips
      ..clear()
      ..addAll(_mockClips());
  }

  List<TranscriptSegment> _mockTranscript() {
    final lines = <List<Object>>[
      [0, 6, "Good morning, church. It's good to see every one of you today."],
      [6, 8, '', true], // silence gap, collapsed in the UI
      [8, 19, "I want to talk about something that's been on my heart all week — the idea that faith isn't the absence of fear."],
      [19, 27, "It's choosing to move forward anyway, one step, even when your hands are shaking."],
      [27, 29, '', true],
      [29, 41, "Because here's the truth: nobody who's ever done anything worth doing felt fully ready when they started."],
      [41, 52, "Noah didn't feel ready. Moses didn't feel ready. You are not required to feel ready — you're required to be willing."],
    ];

    var id = 0;
    return lines.map((row) {
      id++;
      final start = Duration(seconds: row[0] as int);
      final end = Duration(seconds: row[1] as int);
      final isSilence = row.length > 3 && row[3] == true;
      return TranscriptSegment(
        id: 's$id',
        start: start,
        end: end,
        text: row[2] as String,
        isSilence: isSilence,
      );
    }).toList();
  }

  List<AiClip> _mockClips() {
    return const [
      AiClip(
        id: 'c1',
        title: "Faith isn't the absence of fear",
        start: Duration(seconds: 8),
        end: Duration(seconds: 27),
        viralScore: 98,
        reason: 'Strong hook + emotional payoff in first 3 seconds.',
      ),
      AiClip(
        id: 'c2',
        title: 'You are not required to feel ready',
        start: Duration(seconds: 29),
        end: Duration(seconds: 52),
        viralScore: 91,
        reason: 'Quotable closing line, high rewatch potential.',
      ),
      AiClip(
        id: 'c3',
        title: 'Good morning, church',
        start: Duration(seconds: 0),
        end: Duration(seconds: 6),
        viralScore: 62,
        reason: 'Low energy opener — works better as a Story teaser.',
      ),
    ];
  }
}

enum EditorTool { captions, audio, aiCuts, overlays }

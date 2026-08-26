import 'package:flutter_test/flutter_test.dart';
import 'package:luxstudio/models/ai_clip.dart';
import 'package:luxstudio/models/video_project.dart';
import 'package:luxstudio/services/project_dashboard.dart';
import 'package:luxstudio/services/project_store.dart';

ProjectSnapshot _snapshot({bool hasExported = false, bool hasClips = false}) {
  final project = VideoProject(
    id: 'p1',
    fileName: 'sermon.mp4',
    sourcePath: '/tmp/sermon.mp4',
    workingPath: '/tmp/sermon.mp4',
    rawDuration: const Duration(minutes: 10),
    processedDuration: const Duration(minutes: 10),
    width: 1080,
    height: 1920,
    importedAt: DateTime(2026, 1, 1),
    hasExported: hasExported,
  );
  return ProjectSnapshot(
    project: project,
    transcript: const [],
    suggestedClips: hasClips
        ? [
            AiClip(
              id: 'c1',
              title: 'Clip',
              start: Duration.zero,
              end: const Duration(seconds: 30),
              viralScore: 80,
              reason: 'r',
            ),
          ]
        : const [],
    silenceRanges: const [],
    selectedClipId: null,
    brandingPresets: const [],
  );
}

void main() {
  group('deriveProjectStatus', () {
    test('is editing when there are no clips and no export', () {
      expect(deriveProjectStatus(_snapshot()), ProjectDashboardStatus.editing);
    });

    test('is clipsReady once clips exist', () {
      expect(deriveProjectStatus(_snapshot(hasClips: true)), ProjectDashboardStatus.clipsReady);
    });

    test('is exported once a clip has been exported, even with no clips left', () {
      expect(deriveProjectStatus(_snapshot(hasExported: true)), ProjectDashboardStatus.exported);
    });
  });

  group('relativeUpdatedLabel', () {
    final now = DateTime(2026, 1, 10, 12, 0, 0);

    test('just now for under a minute', () {
      expect(relativeUpdatedLabel(now.subtract(const Duration(seconds: 10)), now: now), 'Updated just now');
    });

    test('minutes for under an hour', () {
      expect(relativeUpdatedLabel(now.subtract(const Duration(minutes: 5)), now: now), 'Updated 5m ago');
    });

    test('hours for under a day', () {
      expect(relativeUpdatedLabel(now.subtract(const Duration(hours: 2)), now: now), 'Updated 2h ago');
    });

    test('yesterday for exactly one day', () {
      expect(relativeUpdatedLabel(now.subtract(const Duration(days: 1)), now: now), 'Updated yesterday');
    });

    test('days for under a week', () {
      expect(relativeUpdatedLabel(now.subtract(const Duration(days: 3)), now: now), 'Updated 3 days ago');
    });
  });

  group('formatProjectDuration', () {
    test('formats under an hour as m:ss', () {
      expect(formatProjectDuration(const Duration(minutes: 48, seconds: 12)), '48:12');
    });

    test('formats an hour or more as h:mm:ss', () {
      expect(formatProjectDuration(const Duration(hours: 1, minutes: 2, seconds: 33)), '1:02:33');
    });
  });
}

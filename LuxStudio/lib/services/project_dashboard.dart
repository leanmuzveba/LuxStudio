import 'project_store.dart';

/// The status pill shown on a Home dashboard project card.
enum ProjectDashboardStatus { editing, clipsReady, exported }

/// Derives [ProjectDashboardStatus] from a saved [ProjectSnapshot] — pure
/// logic, unit-tested directly rather than through a widget.
ProjectDashboardStatus deriveProjectStatus(ProjectSnapshot snapshot) {
  if (snapshot.project.hasExported) return ProjectDashboardStatus.exported;
  if (snapshot.suggestedClips.isNotEmpty) return ProjectDashboardStatus.clipsReady;
  return ProjectDashboardStatus.editing;
}

/// A short "Updated 2h ago" / "Updated yesterday" / "Updated 3 days ago"
/// label for [updatedAt] relative to [now] (injectable so it's testable
/// without depending on the real clock).
String relativeUpdatedLabel(DateTime updatedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(updatedAt);
  if (diff.inMinutes < 1) return 'Updated just now';
  if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Updated yesterday';
  if (diff.inDays < 7) return 'Updated ${diff.inDays} days ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return 'Updated $weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  return 'Updated ${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';
}

/// Formats [d] as `m:ss` under an hour, `h:mm:ss` at or above one.
String formatProjectDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:$s';
  }
  return '$m:$s';
}

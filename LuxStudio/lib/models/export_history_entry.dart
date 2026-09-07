/// One completed (or failed) clip export — V2 Decision #3's export
/// history, scoped above any single project (see
/// `backend/app/routers/exports.py`'s `history_router`). Persists
/// independent of the source project's own storage, so it (and its file)
/// survive that project being TTL-swept.
class ExportHistoryEntry {
  final String id;
  final String status; // 'done' | 'error'
  final String projectTitle;
  final String clipTitle;
  final Duration duration;
  final int? sizeBytes;
  final String? error;
  final DateTime createdAt;
  final String? downloadUrl;

  const ExportHistoryEntry({
    required this.id,
    required this.status,
    required this.projectTitle,
    required this.clipTitle,
    required this.duration,
    required this.sizeBytes,
    required this.error,
    required this.createdAt,
    required this.downloadUrl,
  });

  bool get isDone => status == 'done';

  factory ExportHistoryEntry.fromJson(Map<String, dynamic> json) => ExportHistoryEntry(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'done',
        projectTitle: json['projectTitle'] as String? ?? 'Untitled Project',
        clipTitle: json['clipTitle'] as String? ?? 'Untitled Clip',
        duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
        error: json['error'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        downloadUrl: json['downloadUrl'] as String?,
      );
}

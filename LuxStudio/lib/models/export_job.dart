/// Where one clip's batch export currently stands.
enum ExportJobStatus { queued, processing, done, failed }

/// One clip's slot in a batch export — [AppState] keeps a `Map<clipId,
/// ExportJob>` covering every clip with `includeInExport` set, so the
/// Export screen can show independent per-clip progress.
class ExportJob {
  final ExportJobStatus status;
  final double progress;
  final String? outputPath;
  final String? error;

  const ExportJob({
    this.status = ExportJobStatus.queued,
    this.progress = 0,
    this.outputPath,
    this.error,
  });

  ExportJob copyWith({
    ExportJobStatus? status,
    double? progress,
    String? outputPath,
    String? error,
  }) =>
      ExportJob(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        outputPath: outputPath ?? this.outputPath,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'progress': progress,
        'outputPath': outputPath,
        'error': error,
      };

  factory ExportJob.fromJson(Map<String, dynamic> json) => ExportJob(
        status: ExportJobStatus.values.byName(json['status'] as String? ?? 'queued'),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        outputPath: json['outputPath'] as String?,
        error: json['error'] as String?,
      );
}

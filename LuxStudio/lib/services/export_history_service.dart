import '../models/export_history_entry.dart';
import 'api_client.dart';

/// Talks to the backend's export history endpoints (`backend/app/routers
/// /exports.py`'s `history_router`, V2 Decision #3) — every completed or
/// failed export, independent of any one project.
class ExportHistoryService {
  ExportHistoryService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ExportHistoryEntry>> list() async => (await _apiClient.getJsonList('/exports/history'))
      .map((e) => ExportHistoryEntry.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<void> delete(String id) => _apiClient.delete('/exports/history/$id');
}

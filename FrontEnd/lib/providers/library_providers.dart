// FrontEnd/lib/providers/library_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/api_client.dart';
import '../services/api/api_config.dart';

/// Subtitle projects, newest-first, from `/subtitles/list/projects`.
/// Shared by the Projects screen and the Dashboard.
final projectsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.projectsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['projects'] ?? []);
});

/// Export history, newest-first, from `/subtitles/list/exports`.
/// Shared by the Exports screen and the Dashboard.
final exportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.exportsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['exports'] ?? []);
});

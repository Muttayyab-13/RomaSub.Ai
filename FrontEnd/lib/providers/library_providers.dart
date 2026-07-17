// FrontEnd/lib/providers/library_providers.dart
/// Shared read-side data providers for the user's library — the lists and
/// status the Projects, Exports, and Dashboard screens all read.
///
/// Grouped in one file (rather than the folder's usual one-provider-per-file)
/// because these are small, related, read-only list providers consumed across
/// several screens. Note the deliberate plural name: a singular
/// `projects_provider.dart` would collide with the unrelated legacy
/// `project_provider.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/api_client.dart';
import '../services/api/api_config.dart';
import '../models/system_health.dart';

/// Subtitle projects, newest-first, from `/subtitles/list/projects`.
/// Consumed by the Projects screen; will also feed the Dashboard.
final projectsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.projectsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['projects'] ?? []);
});

/// Export history, newest-first, from `/subtitles/list/exports`.
/// Consumed by the Exports screen; will also feed the Dashboard.
final exportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.exportsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['exports'] ?? []);
});

/// Honest system status from `GET /health`. Returns [SystemHealth.unreachable]
/// instead of throwing, so the UI shows a red "Unreachable" state rather than
/// an error box.
final systemHealthProvider =
    FutureProvider.autoDispose<SystemHealth>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.dio.get(ApiConfig.health);
    final data = response.data as Map<String, dynamic>;
    return SystemHealth.fromJson(data);
  } catch (e) {
    if (kDebugMode) debugPrint('systemHealthProvider: $e');
    return const SystemHealth.unreachable();
  }
});

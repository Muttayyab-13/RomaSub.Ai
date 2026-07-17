// FrontEnd/lib/models/system_health.dart

/// An honest view over `GET /health`.
///
/// The backend's `status`/`database` fields are hardcoded literals and are
/// deliberately ignored — the only real signal is whether the call returned
/// ([reachable]) plus the configured model strings it reports.
class SystemHealth {
  /// True when `GET /health` returned a response. This is the one hard fact.
  final bool reachable;

  /// Configured ASR model (e.g. "whisper-large-v3-turbo"), or null.
  final String? whisperModel;

  /// Configured transliteration model, or null.
  final String? transliterationModel;

  /// Configured transliteration device (e.g. "cpu"/"cuda"), or null.
  final String? device;

  const SystemHealth({
    required this.reachable,
    this.whisperModel,
    this.transliterationModel,
    this.device,
  });

  /// The red fallback used when the health call fails or times out.
  const SystemHealth.unreachable()
    : reachable = false,
      whisperModel = null,
      transliterationModel = null,
      device = null;

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    String? str(dynamic v) => v?.toString();
    return SystemHealth(
      reachable: true,
      whisperModel: str(json['whisper_model']),
      transliterationModel: str(json['m2m100_model']),
      device: str(json['transliteration_device']),
    );
  }

  @override
  String toString() =>
      'SystemHealth(reachable: $reachable, whisperModel: $whisperModel, '
      'transliterationModel: $transliterationModel, device: $device)';
}

/// Convenience constants for the dashboard rail's loading/error branches,
/// so the status card always has a concrete value to render.
class SystemHealthLoadingPlaceholder {
  const SystemHealthLoadingPlaceholder._();

  /// Shown while `/health` is in flight — reachable-unknown treated as up,
  /// with no model info yet.
  static const SystemHealth value = SystemHealth(reachable: true);

  /// Shown when the provider errored outright.
  static const SystemHealth unreachable = SystemHealth.unreachable();
}

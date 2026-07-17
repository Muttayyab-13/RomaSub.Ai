// FrontEnd/lib/widgets/dashboard/system_status_card.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/app_palette.dart';
import '../../core/design/app_typography.dart';
import '../../models/system_health.dart';

/// The honest system-status card. Shows one real reachability signal and the
/// configured model strings — never a fabricated backend label, never the
/// word "Translation".
class SystemStatusCard extends StatelessWidget {
  final SystemHealth health;

  const SystemStatusCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ok = health.reachable;
    final dotColor = ok ? AppPalette.success : scheme.error;
    final statusLabel = ok ? AppStrings.dashOnline : AppStrings.dashUnreachable;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.dashSystemStatus,
                style: text.labelSmall?.copyWith(letterSpacing: 0.5),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Text(
                    statusLabel,
                    style: text.bodySmall?.copyWith(
                      color: dotColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _row(context, AppStrings.dashTranscription,
              health.whisperModel ?? AppStrings.dashUnknownModel),
          const SizedBox(height: AppSizes.sm),
          _row(context, AppStrings.dashTransliteration, _transliterationValue()),
        ],
      ),
    );
  }

  String _transliterationValue() {
    final model = health.transliterationModel;
    if (model == null) return AppStrings.dashUnknownModel;
    final device = health.device;
    return device == null ? model : '$model · $device';
  }

  Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed label column so the two rows' values align.
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypography.mono(size: 12, color: scheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

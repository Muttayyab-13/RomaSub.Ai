// FrontEnd/lib/widgets/dashboard/stat_card.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

/// A single stat: icon + uppercase label, with a large number beneath.
/// [value] is null while the source is loading, shown as an em dash.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSizes.iconSm, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSizes.xs),
              Expanded(
                child: Text(
                  label,
                  style: text.labelSmall?.copyWith(letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            value ?? '—',
            style: text.headlineMedium?.copyWith(color: scheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

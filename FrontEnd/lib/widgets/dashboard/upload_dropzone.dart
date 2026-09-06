// FrontEnd/lib/widgets/dashboard/upload_dropzone.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/app_palette.dart';

/// The dashed upload target on the dashboard. Tapping anywhere fires [onTap]
/// (opens the file picker). [compact] drops the chip row on narrow layouts.
class UploadDropzone extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const UploadDropzone({super.key, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: DottedBorderBox(
        color: scheme.outlineVariant,
        radius: AppSizes.radiusLg,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.xl),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: AppSizes.iconLg,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                AppStrings.dashUploadTitle,
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                AppStrings.dashUploadSubtitle,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSizes.md),
              if (compact)
                Text(
                  AppStrings.dashUploadTapHint,
                  style: text.bodySmall?.copyWith(color: scheme.primary),
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    _chip(context, Icons.movie_outlined, 'MP4, MOV, MKV'),
                    _chip(context, Icons.audio_file_outlined, 'MP3, WAV'),
                    _chip(
                      context,
                      Icons.warning_amber_rounded,
                      AppStrings.dashMaxSize,
                      emphasize: true,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label, {
    bool emphasize = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;
    final fg = emphasize ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        // The subtle teal wash has a light and a dark variant; picking by
        // brightness avoids a near-white pill glaring on the dark dropzone.
        color: emphasize
            ? (isDark ? AppPalette.tealSubtleDark : AppPalette.tealSubtle)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: emphasize
              ? scheme.primary.withValues(alpha: 0.2)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSizes.xs),
          Text(label, style: text.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// A rectangle with a dashed border, painted with a [CustomPainter] since
/// Flutter has no built-in dashed border.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final len = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, len), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}

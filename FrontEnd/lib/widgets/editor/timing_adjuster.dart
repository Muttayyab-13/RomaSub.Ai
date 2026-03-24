import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../models/subtitle_project_model.dart';

/// Time spinner widget for adjusting start/end times in HH:MM:SS,mmm format
class TimingAdjuster extends StatelessWidget {
  final String label;
  final double value; // seconds
  final ValueChanged<double> onChanged;

  const TimingAdjuster({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontXs,
            fontWeight: FontWeight.w500,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceVariant(isDark),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: Border.all(color: AppColors.getBorder(isDark)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decrement
              InkWell(
                onTap: () {
                  final newVal = (value - 0.1).clamp(0.0, double.infinity);
                  onChanged(newVal);
                },
                child: Icon(
                  Icons.remove_rounded,
                  size: 16,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
              const SizedBox(width: 6),

              // Time display
              Text(
                EditableSegment.formatTimestamp(value),
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(width: 6),

              // Increment
              InkWell(
                onTap: () {
                  onChanged(value + 0.1);
                },
                child: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

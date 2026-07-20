import 'package:flutter/material.dart';

/// A single Dark Mode row. Pure: [isDark] in, [onChanged] out — the screen wires
/// it to themeProvider (persisted to shared_preferences 'is_dark_mode').
class AppearanceRow extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;
  const AppearanceRow({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dark Mode', style: text.bodyMedium),
              Text(
                'Use the dark colour scheme',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Switch(value: isDark, onChanged: onChanged),
      ],
    );
  }
}

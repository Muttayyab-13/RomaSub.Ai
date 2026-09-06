// FrontEnd/lib/widgets/realtime/live_transcript_panel.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/design/app_palette.dart';
import '../../core/design/app_typography.dart';
import '../../models/subtitle_project_model.dart';

/// Live transcript list for the realtime viewer.
///
/// Pure presentation: each row shows the mono timecode, the Roman-Urdu line,
/// and the real Urdu-script line (Nastaliq, RTL). There is deliberately no
/// English gloss line and no "Translating…" / blinking-cursor affordance —
/// neither exists in the real data, and RomaSub.AI never translates.
class LiveTranscriptPanel extends StatelessWidget {
  final List<EditableSegment> segments;
  final int? currentIndex;

  /// Optional — the hosting screen owns auto-scroll behaviour.
  final ScrollController? controller;

  const LiveTranscriptPanel({
    super.key,
    required this.segments,
    required this.currentIndex,
    this.controller,
  });

  static String _timecode(double startSeconds) {
    final s = startSeconds.floor();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Text(
            'LIVE TRANSCRIPT',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: segments.isEmpty
              ? Center(
                  child: Text(
                    'Waiting for subtitles…',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  itemCount: segments.length,
                  itemBuilder: (context, index) {
                    final seg = segments[index];
                    final isCurrent = index == currentIndex;
                    return _TranscriptRow(
                      segment: seg,
                      isCurrent: isCurrent,
                      timecode: _timecode(seg.start),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TranscriptRow extends StatelessWidget {
  final EditableSegment segment;
  final bool isCurrent;
  final String timecode;

  const _TranscriptRow({
    required this.segment,
    required this.isCurrent,
    required this.timecode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    final highlightColor = isDark
        ? AppPalette.tealSubtleDark
        : AppPalette.tealSubtle;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      decoration: BoxDecoration(
        color: isCurrent ? highlightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border(
          left: BorderSide(
            color: isCurrent ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timecode,
            style: textTheme.bodySmall?.copyWith(
              fontFamily: AppTypography.monoFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(segment.romanUrduText, style: textTheme.bodyMedium),
          const SizedBox(height: AppSizes.xs),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              segment.urduText,
              style: AppTypography.urdu(
                size: textTheme.bodyMedium?.fontSize ?? AppSizes.fontSm,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

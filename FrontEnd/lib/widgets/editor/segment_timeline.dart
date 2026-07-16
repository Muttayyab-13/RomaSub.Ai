// FrontEnd/lib/widgets/editor/segment_timeline.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/editor_theme.dart';
import '../../models/subtitle_project_model.dart';

/// A single segment block on the timeline.
class TimelineBlock extends StatelessWidget {
  final EditableSegment segment;
  final bool isSelected;
  final double pixelsPerSecond;
  final VoidCallback onTap;

  const TimelineBlock({
    super.key,
    required this.segment,
    required this.isSelected,
    required this.pixelsPerSecond,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = Theme.of(context).extension<EditorTheme>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: segment.duration * pixelsPerSecond,
        decoration: BoxDecoration(
          color:
              isSelected ? editor.timelineBlockSelected : editor.timelineBlock,
          border: Border.all(
            color: isSelected ? editor.timelineBlockBorder : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          segment.displayText,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: AppTypography.latin(size: 11, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// The editor's timeline: segment blocks on a time axis, with a playhead.
///
/// Deliberately has NO waveform. The backend exposes no peaks data, so a
/// waveform would need a new FFmpeg endpoint. Blocks give the spatial sense
/// of pacing and gaps using timings we already hold.
class SegmentTimeline extends StatelessWidget {
  static const double height = 132.0;
  static const double rulerHeight = 20.0;
  static const double blockAreaHeight = 56.0;
  static const Key playheadKey = Key('timeline-playhead');

  final List<EditableSegment> segments;
  final double positionSeconds;
  final double durationSeconds;
  final int? selectedIndex;
  final double pixelsPerSecond;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onSelect;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const SegmentTimeline({
    super.key,
    required this.segments,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.selectedIndex,
    required this.pixelsPerSecond,
    required this.onSeek,
    required this.onSelect,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  /// Tick spacing in seconds, chosen so ticks stay ~60px apart at any zoom.
  double get _tickInterval {
    const targetPx = 60.0;
    final raw = targetPx / pixelsPerSecond;
    for (final candidate in const [0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]) {
      if (raw <= candidate) return candidate;
    }
    return 300.0;
  }

  String _formatTick(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = Theme.of(context).extension<EditorTheme>()!;
    final trackWidth = durationSeconds * pixelsPerSecond;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: editor.timelineTrack,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          _buildHeader(context, scheme),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  onSeek(
                    (details.localPosition.dx / pixelsPerSecond)
                        .clamp(0.0, durationSeconds),
                  );
                },
                child: SizedBox(
                  width: trackWidth,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RulerPainter(
                            interval: _tickInterval,
                            pixelsPerSecond: pixelsPerSecond,
                            duration: durationSeconds,
                            color: scheme.outlineVariant,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        height: rulerHeight,
                        left: 0,
                        right: 0,
                        child: _buildTickLabels(scheme),
                      ),
                      Positioned(
                        top: rulerHeight + 4,
                        height: blockAreaHeight,
                        left: 0,
                        right: 0,
                        child: _buildBlocks(),
                      ),
                      Positioned(
                        key: playheadKey,
                        left: (positionSeconds * pixelsPerSecond)
                            .clamp(0.0, trackWidth),
                        top: 0,
                        bottom: 0,
                        width: 2,
                        child: Container(color: editor.playhead),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
        child: Row(
          children: [
            Text(
              'TIMELINE',
              style: AppTypography.latin(
                size: 11,
                weight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            IconButton(
              iconSize: 16,
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Zoom in',
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: onZoomIn,
            ),
            IconButton(
              iconSize: 16,
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: onZoomOut,
            ),
            const Spacer(),
            Text(
              'Scale: ${_tickInterval.toStringAsFixed(_tickInterval < 1 ? 1 : 0)}s',
              style: AppTypography.mono(
                size: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickLabels(ColorScheme scheme) {
    final labels = <Widget>[];
    for (double t = 0; t <= durationSeconds; t += _tickInterval) {
      labels.add(Positioned(
        left: t * pixelsPerSecond + 3,
        top: 2,
        child: Text(
          _formatTick(t),
          style: AppTypography.mono(size: 9, color: scheme.onSurfaceVariant),
        ),
      ));
    }
    return Stack(children: labels);
  }

  Widget _buildBlocks() {
    return Stack(
      children: [
        for (var i = 0; i < segments.length; i++)
          Positioned(
            left: segments[i].start * pixelsPerSecond,
            top: 0,
            bottom: 0,
            child: TimelineBlock(
              segment: segments[i],
              isSelected: selectedIndex == i,
              pixelsPerSecond: pixelsPerSecond,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double interval;
  final double pixelsPerSecond;
  final double duration;
  final Color color;

  _RulerPainter({
    required this.interval,
    required this.pixelsPerSecond,
    required this.duration,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double t = 0; t <= duration; t += interval) {
      final x = t * pixelsPerSecond;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.interval != interval ||
      old.pixelsPerSecond != pixelsPerSecond ||
      old.duration != duration ||
      old.color != color;
}

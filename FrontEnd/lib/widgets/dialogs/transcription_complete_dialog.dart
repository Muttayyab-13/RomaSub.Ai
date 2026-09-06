import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/design/app_palette.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/base_theme.dart';

// The success header is the product's "caption studio" surface — always dark
// navy with a teal glow, matching the auth hero and the sidebar. Captions are
// watched on a dark stage, so the reveal happens there too.
const Color _navy = AppPalette.videoStage; // #0B1C30
const Color _teal = AppPalette.primaryFixed; // #89F5E7
const Color _onNav = Color(0xFFEDF6F3);
const Color _onNavMuted = Color(0xFF9DB2B6);

/// Shown the moment a transcription finishes: confirms success, surfaces the
/// key facts, previews the captions in both scripts, and routes to
/// Export / Details / Edit.
///
/// Redesigned onto the shared design system ([buildBaseTheme] + [AppPalette]).
/// The export menu, its values, and every callback are unchanged.
class TranscriptionCompleteDialog extends StatefulWidget {
  final String filename;
  final String duration;
  final int segmentCount;
  final String language;
  final String previewText;
  final String? romanUrduPreviewText;

  /// Whether the source is a video — gates the captioned-video export options.
  final bool isVideo;

  /// Export a text subtitle format ('srt' | 'vtt' | 'txt').
  final ValueChanged<String> onExport;

  /// Render and download a captioned video ('hardsub' | 'softsub').
  final ValueChanged<String> onExportVideo;
  final VoidCallback onViewDetails;
  final VoidCallback onEdit;

  const TranscriptionCompleteDialog({
    super.key,
    required this.filename,
    required this.duration,
    required this.segmentCount,
    required this.language,
    required this.previewText,
    this.romanUrduPreviewText,
    required this.isVideo,
    required this.onExport,
    required this.onExportVideo,
    required this.onViewDetails,
    required this.onEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required String filename,
    required String duration,
    required int segmentCount,
    required String language,
    required String previewText,
    String? romanUrduPreviewText,
    required bool isVideo,
    required ValueChanged<String> onExport,
    required ValueChanged<String> onExportVideo,
    required VoidCallback onViewDetails,
    required VoidCallback onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TranscriptionCompleteDialog(
        filename: filename,
        duration: duration,
        segmentCount: segmentCount,
        language: language,
        previewText: previewText,
        romanUrduPreviewText: romanUrduPreviewText,
        isVideo: isVideo,
        onExport: onExport,
        onExportVideo: onExportVideo,
        onViewDetails: onViewDetails,
        onEdit: onEdit,
      ),
    );
  }

  @override
  State<TranscriptionCompleteDialog> createState() =>
      _TranscriptionCompleteDialogState();
}

class _TranscriptionCompleteDialogState
    extends State<TranscriptionCompleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Respect the system "reduce motion" setting: jump straight to the final
    // state instead of animating the scale-in.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _animationController.value = 1.0;
    } else {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Theme(
        data: buildBaseTheme(isDark),
        child: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return Dialog(
              backgroundColor: scheme.surface,
              insetPadding: const EdgeInsets.all(AppSizes.lg),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXl + 4),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                  maxHeight: 700,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    // Stats + preview scroll; the actions stay pinned below so
                    // the primary Export is always reachable.
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.lg,
                          AppSizes.lg,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _statsRow(context),
                            const SizedBox(height: AppSizes.lg),
                            _previewSection(context),
                          ],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        child: _actions(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // -- Navy success header ----------------------------------------------------

  Widget _header() {
    return Container(
      width: double.infinity,
      color: _navy,
      child: Stack(
        children: [
          // Faint teal glow behind the mark — the auth-hero atmosphere.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 1.1,
                    colors: [
                      _teal.withValues(alpha: 0.14),
                      _navy.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.xl,
              AppSizes.lg,
              AppSizes.lg,
            ),
            child: Column(
              children: [
                _successMark(),
                const SizedBox(height: AppSizes.md),
                Text(
                  'Transcription complete',
                  textAlign: TextAlign.center,
                  style: AppTypography.latin(
                    size: 22,
                    weight: FontWeight.w800,
                    color: _onNav,
                  ),
                ),
                const SizedBox(height: AppSizes.sm + 2),
                _filenamePill(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _successMark() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _teal.withValues(alpha: 0.14),
        border: Border.all(color: _teal.withValues(alpha: 0.55), width: 2),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.25),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: _teal, size: 32),
    );
  }

  Widget _filenamePill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm + 4,
        vertical: AppSizes.xs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 15, color: _onNavMuted),
          const SizedBox(width: AppSizes.sm),
          Flexible(
            child: Text(
              widget.filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.latin(
                size: 13,
                weight: FontWeight.w500,
                color: _onNav.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Stats ------------------------------------------------------------------

  Widget _statsRow(BuildContext context) {
    // IntrinsicHeight bounds the row inside the scroll view and keeps all three
    // tiles the same height regardless of their value's line metrics.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _statTile(
              context,
              'Duration',
              widget.duration,
              Icons.schedule_rounded,
              mono: true,
            ),
          ),
          const SizedBox(width: AppSizes.sm + 4),
          Expanded(
            child: _statTile(
              context,
              'Segments',
              '${widget.segmentCount}',
              Icons.segment_rounded,
              mono: true,
            ),
          ),
          const SizedBox(width: AppSizes.sm + 4),
          Expanded(
            child: _statTile(
              context,
              'Language',
              widget.language,
              Icons.translate_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool mono = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.md,
        horizontal: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: AppSizes.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? AppTypography.mono(
                    size: 17,
                    weight: FontWeight.w700,
                    color: scheme.onSurface,
                  )
                : AppTypography.latin(
                    size: 16,
                    weight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.latin(
              size: 11,
              weight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // -- Dual-script preview (the signature) ------------------------------------

  Widget _previewSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasRoman = widget.romanUrduPreviewText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Preview', style: text.labelLarge),
            TextButton.icon(
              onPressed: _showFullText,
              icon: const Icon(Icons.open_in_full_rounded, size: 15),
              label: const Text('View full'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.xs,
                ),
                textStyle: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The active-caption cue, reused from the editor.
                Container(width: 3, color: scheme.primary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: hasRoman
                        ? _dualScript(context)
                        : _singleScript(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dualScript(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.romanUrduPreviewText!,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.latin(
            size: 14,
            weight: FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: AppSizes.sm),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            widget.previewText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.urdu(
              size: 14,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _singleScript(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        widget.previewText,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.urdu(size: 14, color: scheme.onSurface),
      ),
    );
  }

  // -- Actions ----------------------------------------------------------------

  Widget _actions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    OutlinedButton secondary({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          onTap();
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(vertical: AppSizes.md - 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      children: [
        _exportMenu(context),
        const SizedBox(height: AppSizes.sm + 4),
        Row(
          children: [
            Expanded(
              child: secondary(
                icon: Icons.visibility_outlined,
                label: 'View details',
                onTap: widget.onViewDetails,
              ),
            ),
            const SizedBox(width: AppSizes.sm + 4),
            Expanded(
              child: secondary(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: widget.onEdit,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: AppTypography.latin(
              size: AppSizes.fontSm,
              weight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// Full-width "Export ▾" menu mirroring the editor toolbar: text formats are
  /// always available; captioned-video exports show only for video sources.
  Widget _exportMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'Export',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        // Dismiss the completion dialog, then hand off to the caller. Video
        // renders surface their own progress UI on the underlying screen.
        Navigator.of(context).pop();
        if (value == 'video_hardsub') {
          widget.onExportVideo('hardsub');
        } else if (value == 'video_softsub') {
          widget.onExportVideo('softsub');
        } else {
          widget.onExport(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'srt', child: Text('Export as SRT')),
        const PopupMenuItem(value: 'vtt', child: Text('Export as VTT')),
        const PopupMenuItem(value: 'txt', child: Text('Export as TXT')),
        if (widget.isVideo) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'video_hardsub',
            child: Text('Video — burned-in captions'),
          ),
          const PopupMenuItem(
            value: 'video_softsub',
            child: Text('Video — toggleable captions'),
          ),
        ],
      ],
      child: Container(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_rounded, size: 20, color: scheme.onPrimary),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Export',
              style: AppTypography.latin(
                size: 15,
                weight: FontWeight.w600,
                color: scheme.onPrimary,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 22,
              color: scheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }

  void _showFullText() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasRoman = widget.romanUrduPreviewText != null;

    showDialog(
      context: context,
      builder: (context) => Theme(
        data: buildBaseTheme(isDark),
        child: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            final text = Theme.of(context).textTheme;
            return Dialog(
              backgroundColor: scheme.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 520,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.lg,
                        AppSizes.md,
                        AppSizes.sm,
                        AppSizes.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: AppSizes.iconSm,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              'Full transcript',
                              style: text.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasRoman) ...[
                              _fullBlock(
                                context,
                                'Roman Urdu',
                                widget.romanUrduPreviewText!,
                                roman: true,
                              ),
                              const SizedBox(height: AppSizes.lg),
                              _fullBlock(
                                context,
                                'Urdu',
                                widget.previewText,
                                roman: false,
                              ),
                            ] else
                              _fullBlock(
                                context,
                                'Urdu',
                                widget.previewText,
                                roman: false,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fullBlock(
    BuildContext context,
    String label,
    String body, {
    required bool roman,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.latin(
            size: 11,
            weight: FontWeight.w700,
            color: scheme.primary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Directionality(
          textDirection: roman ? TextDirection.ltr : TextDirection.rtl,
          child: SelectableText(
            body,
            textAlign: roman ? TextAlign.left : TextAlign.right,
            style: roman
                ? AppTypography.latin(size: 15, color: scheme.onSurface)
                : AppTypography.urdu(size: 15, color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}

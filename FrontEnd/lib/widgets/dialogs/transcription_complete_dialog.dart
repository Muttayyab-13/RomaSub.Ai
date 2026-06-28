import 'package:flutter/material.dart';

/// Clean and Modern Transcription Complete Dialog
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
    Key? key,
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
  }) : super(key: key);

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 650),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with success icon
                _buildHeader(),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Stats cards
                        _buildStatsRow(),
                        const SizedBox(height: 20),

                        // Preview section
                        _buildPreviewSection(),
                        const SizedBox(height: 24),

                        // Action buttons
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Success icon with black background
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary, // Adapts to theme (Black/White)
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.check_rounded,
              color: theme.colorScheme.onPrimary, // White/Black
              size: 36,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Transcription Complete!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // Filename in a subtle chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.filename,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Duration',
            widget.duration,
            Icons.timer_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Segments',
            '${widget.segmentCount}',
            Icons.format_list_numbered,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Language', widget.language, Icons.language),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.secondary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Preview',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showFullText(),
              icon: Icon(
                Icons.open_in_full,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                'View Full',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Text(
            widget.romanUrduPreviewText ?? widget.previewText,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface,
              height: 1.8,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textDirection: widget.romanUrduPreviewText != null
                ? TextDirection.ltr
                : TextDirection.rtl,
            textAlign: widget.romanUrduPreviewText != null
                ? TextAlign.left
                : TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Primary: Export menu (SRT/VTT/TXT, plus captioned video for videos)
        _buildExportMenu(theme),
        const SizedBox(height: 12),

        // Secondary buttons row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onViewDetails();
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.onSurface),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onEdit();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.onSurface),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Close button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Full-width "Export ▾" menu mirroring the editor toolbar: text formats are
  /// always available; captioned-video exports show only for video sources.
  Widget _buildExportMenu(ThemeData theme) {
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_rounded,
              size: 20,
              color: theme.colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'Export',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 22,
              color: theme.colorScheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }

  void _showFullText() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.romanUrduPreviewText != null
                            ? 'Roman Urdu Transliteration'
                            : 'Full Transcription',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText(
                    widget.romanUrduPreviewText ?? widget.previewText,
                    textDirection: widget.romanUrduPreviewText != null
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                    textAlign: widget.romanUrduPreviewText != null
                        ? TextAlign.left
                        : TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                      height: 2.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} // End of class

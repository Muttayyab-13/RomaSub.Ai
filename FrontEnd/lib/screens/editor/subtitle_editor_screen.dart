import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/design/editor_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../models/transcription_model.dart';
import '../../providers/subtitle_editor_provider.dart';
import '../../providers/video_player_provider.dart';
import '../../services/api/api_config.dart';
import '../../services/media_service.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/editor/editor_toolbar.dart';
import '../../widgets/editor/segment_timeline.dart';
import '../../widgets/editor/video_preview_panel.dart';
import '../../widgets/editor/subtitle_list_panel.dart';
import '../../widgets/editor/text_editor_panel.dart';

/// The subtitle editor.
///
/// Three panels inside the app shell, left to right:
///   - Segment list (flex 3)  — navigate and search
///   - Video + timeline (flex 6) — judge the result
///   - Inspector (flex 3)     — where corrections happen
///
/// Desktop-only. See Documentation/PRODUCT_OVERVIEW.md §6.13 — a mobile
/// layout is an open design problem, not a scaling exercise.
class SubtitleEditorScreen extends ConsumerStatefulWidget {
  final String fileId;
  final TranscriptionModel? transcription;

  const SubtitleEditorScreen({
    super.key,
    required this.fileId,
    this.transcription,
  });

  @override
  ConsumerState<SubtitleEditorScreen> createState() =>
      _SubtitleEditorScreenState();
}

class _SubtitleEditorScreenState extends ConsumerState<SubtitleEditorScreen> {
  late final FocusNode _focusNode;

  static const double _minPixelsPerSecond = 4.0;
  static const double _maxPixelsPerSecond = 200.0;
  double _pixelsPerSecond = 40.0;

  void _zoomIn() => setState(() {
        _pixelsPerSecond = (_pixelsPerSecond * 1.5)
            .clamp(_minPixelsPerSecond, _maxPixelsPerSecond);
      });

  void _zoomOut() => setState(() {
        _pixelsPerSecond = (_pixelsPerSecond / 1.5)
            .clamp(_minPixelsPerSecond, _maxPixelsPerSecond);
      });

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Initialize editor and video player after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeEditor();
    });
  }

  Future<void> _initializeEditor() async {
    // Load subtitle project from backend
    await ref.read(editorNotifierProvider.notifier).loadProject(
          widget.fileId,
          widget.transcription,
        );

    // If the media file no longer exists on the server (e.g. an old recents
    // project whose temp file was cleaned up), show a clear message instead
    // of letting the player spin forever.
    final available =
        await ref.read(mediaServiceProvider).isMediaAvailable(widget.fileId);
    if (!available) {
      ref.read(videoPlayerNotifierProvider.notifier).markUnavailable();
      return;
    }

    // Initialize video player with streaming URL
    final videoUrl = ApiConfig.mediaStreamUrl(widget.fileId);
    await ref.read(videoPlayerNotifierProvider.notifier).initialize(videoUrl);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard shortcuts
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Ctrl+Z - Undo
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        ref.read(editorNotifierProvider.notifier).redo();
      } else {
        ref.read(editorNotifierProvider.notifier).undo();
      }
      return KeyEventResult.handled;
    }

    // Ctrl+Y - Redo
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      ref.read(editorNotifierProvider.notifier).redo();
      return KeyEventResult.handled;
    }

    // Ctrl+S - Save
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      ref.read(editorNotifierProvider.notifier).save();
      return KeyEventResult.handled;
    }

    // Space - Play/Pause (only when not editing text)
    if (event.logicalKey == LogicalKeyboardKey.space) {
      final focus = FocusManager.instance.primaryFocus;
      // Don't intercept space if a text field has focus
      if (focus?.context?.widget is! EditableText) {
        ref.read(videoPlayerNotifierProvider.notifier).togglePlayPause();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The Scaffold now lives inside the scoped theme, so this is what paints
    // behind the Sidebar's margin. The editor is pushed as an opaque route over
    // MainShell, so nothing else would fill that gap.
    return ColoredBox(
      color: AppColors.getBackground(isDark),
      child: Row(
        children: [
          // Outside the scoped theme on purpose — shared with every other screen.
          const Sidebar(selectedIndexOverride: -1),
          Expanded(
            // Scoped: the redesign applies to the editor only. Everything else
            // still uses AppTheme/AppColors until it is redesigned in turn.
            child: Theme(
              data: buildEditorTheme(isDark),
              // Builder is required: without it the subtree below reads the
              // OUTER theme, not the one we just built.
              child: Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  return Focus(
                    focusNode: _focusNode,
                    autofocus: true,
                    onKeyEvent: _handleKeyEvent,
                    child: Scaffold(
                      backgroundColor: scheme.surface,
                      body: editorState.isLoading
                          ? _buildLoadingState(isDark)
                          : (editorState.error != null &&
                                  editorState.project == null)
                              ? _buildErrorState(isDark, editorState.error!)
                              : Column(
                                  children: [
                                    const EditorToolbar(),
                                    if (editorState.error != null)
                                      _buildErrorBanner(
                                          isDark, editorState.error!),
                                    Expanded(child: _buildPanels(editorState)),
                                  ],
                                ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanels(EditorState editorState) {
    return Row(
      children: [
        const Expanded(flex: 3, child: SubtitleListPanel()),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              const Expanded(child: VideoPreviewPanel()),
              _buildTimeline(editorState),
            ],
          ),
        ),
        // The inspector needs width for two side-by-side TimingAdjuster
        // fields showing HH:MM:SS,mmm.
        const Expanded(flex: 3, child: TextEditorPanel()),
      ],
    );
  }

  Widget _buildTimeline(EditorState editorState) {
    final playerState = ref.watch(videoPlayerNotifierProvider);

    // Prefer the project's duration: it survives the media file going away,
    // and the timeline should still render for a project whose video is gone.
    final duration =
        editorState.project?.fileDuration ?? playerState.durationSeconds;
    if (duration <= 0) return const SizedBox.shrink();

    return SegmentTimeline(
      segments: editorState.segments,
      positionSeconds: playerState.positionSeconds,
      durationSeconds: duration,
      selectedIndex: editorState.selectedSegmentIndex,
      pixelsPerSecond: _pixelsPerSecond,
      onSeek: (seconds) =>
          ref.read(videoPlayerNotifierProvider.notifier).seekToSeconds(seconds),
      onSelect: (index) {
        ref.read(editorNotifierProvider.notifier).selectSegment(index);
        ref
            .read(videoPlayerNotifierProvider.notifier)
            .seekToSeconds(editorState.segments[index].start);
      },
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.getPrimary(isDark),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'Loading subtitle editor...',
            style: TextStyle(
              color: AppColors.getTextSecondary(isDark),
              fontSize: AppSizes.fontMd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: AppSizes.iconXl,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            error,
            style: TextStyle(
              color: AppColors.error,
              fontSize: AppSizes.fontMd,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.md),
          ElevatedButton(
            onPressed: () => AppRoutes.back(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: AppSizes.fontXs,
                color: AppColors.error,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () =>
                ref.read(editorNotifierProvider.notifier).clearError(),
          ),
        ],
      ),
    );
  }
}

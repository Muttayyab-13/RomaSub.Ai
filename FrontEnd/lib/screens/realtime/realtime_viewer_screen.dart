import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/design/app_palette.dart';
import '../../core/design/base_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/realtime_subtitle_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/video_player_provider.dart';
import '../../services/api/api_config.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/editor/subtitle_overlay.dart';
import '../../widgets/editor/video_controls.dart';
import '../../widgets/realtime/live_transcript_panel.dart';

/// Real-time subtitle viewer screen.
///
/// Shows video playback with live-streaming subtitles.
/// Phases: connecting → buffering → streaming (playback starts) → complete.
/// On complete, user can transition to the subtitle editor.
///
/// Opts into the redesigned system via a scoped [buildBaseTheme] wrapper
/// around the content column, mirroring `DashboardScreen`. It is pushed
/// full-screen over the shell (not a tab) and keeps its own
/// `Row[Sidebar, Expanded(...)]` structure — the Sidebar stays outside the
/// scoped theme, unstyled, same as every other screen.
class RealtimeViewerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String filename;

  const RealtimeViewerScreen({
    super.key,
    required this.fileId,
    required this.filename,
  });

  @override
  ConsumerState<RealtimeViewerScreen> createState() =>
      _RealtimeViewerScreenState();
}

class _RealtimeViewerScreenState extends ConsumerState<RealtimeViewerScreen> {
  bool _videoStarted = false;
  late final ScrollController _transcriptScrollController;

  @override
  void initState() {
    super.initState();
    _transcriptScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStreaming();
    });
  }

  @override
  void dispose() {
    _transcriptScrollController.dispose();
    super.dispose();
  }

  Future<void> _startStreaming() async {
    // Start the SSE stream
    ref.read(realtimeNotifierProvider.notifier).startStreaming(widget.fileId);
  }

  void _startVideoWhenReady(RealtimeState rtState) {
    if (!_videoStarted && rtState.canPlay) {
      _videoStarted = true;
      final videoUrl = ApiConfig.mediaStreamUrl(widget.fileId);
      final playerNotifier = ref.read(videoPlayerNotifierProvider.notifier);
      playerNotifier.initialize(videoUrl).then((_) {
        playerNotifier.play();
        // Hook seek callback for debounced seek notification
        playerNotifier.onSeekCallback = (seconds) {
          ref.read(realtimeNotifierProvider.notifier).notifySeek(seconds);
        };
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Space - Play/Pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      ref.read(videoPlayerNotifierProvider.notifier).togglePlayPause();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rtState = ref.watch(realtimeNotifierProvider);
    final playerState = ref.watch(videoPlayerNotifierProvider);
    final isDark = ref.watch(themeProvider).isDark;

    // Auto-start video when buffer is ready
    _startVideoWhenReady(rtState);

    // Auto-scroll the live transcript to the newest segment as chunks arrive.
    ref.listen<int>(realtimeNotifierProvider.select((s) => s.segments.length), (
      previous,
      next,
    ) {
      if (previous != null && next > previous) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_transcriptScrollController.hasClients) {
            _transcriptScrollController.animateTo(
              _transcriptScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      // Outside the scoped theme on purpose — shared with every other
      // screen. Paints behind the Sidebar's margin; the realtime viewer is
      // pushed as an opaque route over MainShell, so nothing else fills
      // that gap.
      child: ColoredBox(
        color: AppColors.getBackground(isDark),
        child: Row(
          children: [
            const Sidebar(selectedIndexOverride: -1),
            Expanded(
              // Scoped: the redesign applies to this screen only.
              child: Theme(
                data: buildBaseTheme(isDark),
                // Builder is required: without it the subtree below reads
                // the OUTER theme, not the one we just built.
                child: Builder(
                  builder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    return Scaffold(
                      backgroundColor: scheme.surface,
                      body: Column(
                        children: [
                          // Top bar
                          _buildTopBar(context, rtState),

                          // Video area + live transcript
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child:
                                      rtState.phase ==
                                              RealtimePhase.connecting ||
                                          (rtState.phase ==
                                                  RealtimePhase.buffering &&
                                              !_videoStarted)
                                      ? _buildBufferingState(context, rtState)
                                      : _buildVideoArea(
                                          context,
                                          playerState,
                                          rtState,
                                        ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: _buildTranscriptPanel(
                                    context,
                                    rtState,
                                    playerState,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Progress bar + actions
                          _buildBottomBar(context, rtState),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, RealtimeState rtState) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: scheme.onSurface,
            ),
            tooltip: 'Back to Dashboard',
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
          Icon(
            Icons.live_tv_rounded,
            size: AppSizes.iconSm,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSizes.xs),
          Flexible(
            child: Text(
              widget.filename,
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Phase indicator
          _buildPhaseChip(context, rtState),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(BuildContext context, RealtimeState rtState) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    Color color;
    String label;
    switch (rtState.phase) {
      case RealtimePhase.connecting:
        color = isDark ? AppPalette.warningDark : AppPalette.warning;
        label = 'Connecting...';
      case RealtimePhase.buffering:
        color = isDark ? AppPalette.warningDark : AppPalette.warning;
        label = 'Buffering...';
      case RealtimePhase.streaming:
        color = isDark ? AppPalette.successDark : AppPalette.success;
        label = 'Live';
      case RealtimePhase.complete:
        color = scheme.primary;
        label = 'Complete';
      case RealtimePhase.error:
        color = scheme.error;
        label = 'Error';
      case RealtimePhase.idle:
        color = scheme.onSurfaceVariant;
        label = 'Idle';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rtState.phase == RealtimePhase.streaming)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBufferingState(BuildContext context, RealtimeState rtState) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: scheme.primary),
          const SizedBox(height: AppSizes.md),
          Text(
            rtState.phase == RealtimePhase.connecting
                ? 'Connecting to stream...'
                : 'Preparing subtitles...',
            style: TextStyle(
              fontSize: AppSizes.fontMd,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (rtState.chunksTotal > 0) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              '${rtState.chunksReady}/${rtState.chunksTotal} chunks processed',
              style: TextStyle(
                fontSize: AppSizes.fontXs,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (rtState.error != null) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              rtState.error!,
              style: TextStyle(fontSize: AppSizes.fontSm, color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoArea(
    BuildContext context,
    VideoPlayerState playerState,
    RealtimeState rtState,
  ) {
    // Always dark, in both themes — video is watched against a dark stage
    // regardless of app theme.
    return Container(
      color: AppPalette.videoStage,
      child: playerState.controller != null
          ? Stack(
              children: [
                Center(
                  child: Video(
                    controller: playerState.controller!,
                    controls: NoVideoControls,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                ),
                if (playerState.isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                // Subtitle overlay (reads from realtime provider)
                const Positioned.fill(child: SubtitleOverlay()),
              ],
            )
          : Center(
              child: Text(
                playerState.error ?? 'Loading video...',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
    );
  }

  Widget _buildTranscriptPanel(
    BuildContext context,
    RealtimeState rtState,
    VideoPlayerState playerState,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: LiveTranscriptPanel(
        segments: rtState.segments,
        currentIndex: rtState.getSegmentAtTime(playerState.positionSeconds),
        controller: _transcriptScrollController,
      ),
    );
  }

  /// Progress label shown next to the bar. Never a fabricated percentage —
  /// before the backend reports a chunk total there is nothing honest to
  /// show but the phase itself.
  String _progressLabel(RealtimeState rtState, bool hasTotal) {
    if (hasTotal) return '${rtState.chunksReady}/${rtState.chunksTotal} chunks';
    return rtState.phase == RealtimePhase.connecting
        ? 'Connecting…'
        : 'Buffering…';
  }

  Widget _buildBottomBar(BuildContext context, RealtimeState rtState) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final hasTotal = rtState.chunksTotal > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          // Video controls (when video is loaded)
          if (_videoStarted) const VideoControls(),

          const SizedBox(height: AppSizes.xs),

          // Progress bar — indeterminate until the backend reports a chunk
          // total, determinate (and honest) once it does.
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: hasTotal ? rtState.progress : null,
                    backgroundColor: scheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rtState.phase == RealtimePhase.complete
                          ? (isDark
                                ? AppPalette.successDark
                                : AppPalette.success)
                          : scheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                _progressLabel(rtState, hasTotal),
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                ' | ${rtState.segments.length} subtitles',
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          // Open Editor button (when complete)
          if (rtState.phase == RealtimePhase.complete) ...[
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Create subtitle project, then navigate to editor
                  final project = await ref
                      .read(realtimeNotifierProvider.notifier)
                      .createProjectForEditor(widget.filename);

                  if (project != null && mounted) {
                    // Navigate to editor with the transcription data
                    // The editor needs a TranscriptionModel, but we can
                    // navigate directly since the project is already created.
                    // `this.context` (not the local Builder-scoped `context`
                    // param) so the analyzer can verify it against `mounted`.
                    AppRoutes.replace(
                      this.context,
                      AppRoutes.editor,
                      arguments: {
                        'fileId': widget.fileId,
                        'transcription':
                            null, // Editor will load from existing project
                      },
                    );
                  }
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Open Subtitle Editor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

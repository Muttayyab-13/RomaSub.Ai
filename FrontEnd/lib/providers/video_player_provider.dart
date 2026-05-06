import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// State for the video player
class VideoPlayerState {
  final Player? player;
  final VideoController? controller;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool subtitlesVisible;
  final bool isBuffering;
  final bool isInitialized;
  final String? error;

  VideoPlayerState({
    this.player,
    this.controller,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.subtitlesVisible = true,
    this.isBuffering = false,
    this.isInitialized = false,
    this.error,
  });

  double get positionSeconds => position.inMilliseconds / 1000.0;
  double get durationSeconds => duration.inMilliseconds / 1000.0;

  VideoPlayerState copyWith({
    Player? player,
    VideoController? controller,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? subtitlesVisible,
    bool? isBuffering,
    bool? isInitialized,
    String? error,
  }) {
    return VideoPlayerState(
      player: player ?? this.player,
      controller: controller ?? this.controller,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      subtitlesVisible: subtitlesVisible ?? this.subtitlesVisible,
      isBuffering: isBuffering ?? this.isBuffering,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }

  factory VideoPlayerState.initial() => VideoPlayerState();
}

/// Notifier managing video playback state via media_kit
class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  final List<StreamSubscription> _subscriptions = [];

  /// Optional callback invoked when seekToSeconds is called.
  /// Used by the realtime viewer to send debounced seek notifications.
  void Function(double)? onSeekCallback;

  VideoPlayerNotifier() : super(VideoPlayerState.initial());

  /// Initialize the player with a video URL
  Future<void> initialize(String videoUrl) async {
    final stopwatch = Stopwatch()..start();
    void log(String msg) =>
        debugPrint('[VideoPlayer ${stopwatch.elapsedMilliseconds}ms] $msg');

    try {
      log('initialize() called url=$videoUrl');
      // Dispose previous player if any
      await _disposePlayer();
      log('previous player disposed');

      final player = Player();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          // Disable hardware acceleration to fix blue/corrupted video on Linux
          enableHardwareAcceleration: false,
          // Force software decoding. Without this, hwdec defaults to 'auto'
          // and libmpv tries VDPAU/VAAPI — when those backends are missing
          // (e.g. no libvdpau_nvidia.so) it fails with "Could not open codec"
          // on the affected videos and the texture stays black while audio
          // still plays. enableHardwareAcceleration only controls the
          // renderer (vo), not the decoder.
          hwdec: 'no',
          // Set initial texture size to avoid 1x1 default which crashes
          // mpv's mp_image_crop assertion with software rendering on Linux
          width: 640,
          height: 480,
        ),
      );
      _playerRef = player;
      log('player + controller constructed');

      // Track when controller's platform texture becomes ready and when the
      // first frame is rendered. These are the two checkpoints that have to
      // happen for the video to be visible.
      controller.platform.future.then((_) {
        log('controller.platform ready (texture attached to libmpv)');
      }).catchError((e, st) {
        log('controller.platform FAILED: $e');
        debugPrint(st.toString());
      });
      controller.id.addListener(() {
        log('controller.id changed -> ${controller.id.value}');
      });
      controller.rect.addListener(() {
        log('controller.rect changed -> ${controller.rect.value}');
      });

      state = state.copyWith(
        player: player,
        controller: controller,
        isInitialized: false,
        error: null,
      );

      // Listen to streams
      _subscriptions.add(
        player.stream.playing.listen((playing) {
          if (mounted) state = state.copyWith(isPlaying: playing);
        }),
      );

      _subscriptions.add(
        player.stream.position.listen((position) {
          if (mounted) state = state.copyWith(position: position);
        }),
      );

      _subscriptions.add(
        player.stream.duration.listen((duration) {
          log('duration -> $duration');
          if (mounted) {
            state = state.copyWith(
              duration: duration,
              isInitialized: duration.inMilliseconds > 0,
            );
          }
        }),
      );

      _subscriptions.add(
        player.stream.buffering.listen((buffering) {
          if (mounted) state = state.copyWith(isBuffering: buffering);
        }),
      );

      _subscriptions.add(
        player.stream.volume.listen((volume) {
          if (mounted) state = state.copyWith(volume: volume / 100.0);
        }),
      );

      // Diagnostic streams: these were unsubscribed before, so any libmpv
      // failure (decode error, codec missing, mp_image_crop assertion, etc.)
      // was silently dropped — producing a black video with no error. Surface
      // them now so we can see what is actually going wrong.
      _subscriptions.add(
        player.stream.error.listen((err) {
          log('PLAYER ERROR: $err');
          if (mounted) state = state.copyWith(error: 'Player error: $err');
        }),
      );
      _subscriptions.add(
        player.stream.log.listen((entry) {
          // Only print warnings/errors from mpv to avoid log spam.
          final level = entry.level;
          if (level == 'error' || level == 'warn' || level == 'fatal') {
            log('mpv [$level] ${entry.prefix}: ${entry.text}');
          }
        }),
      );
      _subscriptions.add(
        player.stream.videoParams.listen((p) {
          log('videoParams -> dw=${p.dw} dh=${p.dh} rotate=${p.rotate} '
              'pixelformat=${p.pixelformat}');
        }),
      );
      _subscriptions.add(
        player.stream.tracks.listen((t) {
          log('tracks -> video=${t.video.length} audio=${t.audio.length}');
        }),
      );

      // Open the media
      log('calling player.open()');
      await player.open(Media(videoUrl), play: false);
      log('player.open() returned');
    } catch (e, st) {
      log('initialize() threw: $e');
      debugPrint(st.toString());
      state = state.copyWith(error: 'Failed to load video: $e');
    }
  }

  void play() => state.player?.play();

  void pause() => state.player?.pause();

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seek(Duration position) => state.player?.seek(position);

  void seekToSeconds(double seconds) {
    seek(Duration(milliseconds: (seconds * 1000).round()));
    onSeekCallback?.call(seconds);
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    state.player?.setVolume(clamped * 100);
  }

  void toggleSubtitles() {
    state = state.copyWith(subtitlesVisible: !state.subtitlesVisible);
  }

  Player? _playerRef; // Keep a direct reference for safe disposal

  Future<void> _disposePlayer() async {
    // Clear the controller out of state BEFORE the awaits below. Disposing
    // the Player tears down its VideoController's ValueNotifiers (id, rect,
    // notifier). Any frame that rebuilds while we're awaiting in here would
    // mount the Video widget against a controller whose notifiers have been
    // disposed and crash with "ValueNotifier was used after being disposed".
    // Dropping it from state first makes VideoPreviewPanel unmount the Video
    // widget on the next build, so no widget is left holding the dead
    // notifiers. Note: copyWith uses `?? this.x` so we can't pass null —
    // we have to build a fresh state explicitly. User-facing prefs
    // (subtitlesVisible, volume) are preserved.
    if (_playerRef != null && mounted) {
      state = VideoPlayerState(
        subtitlesVisible: state.subtitlesVisible,
        volume: state.volume,
      );
    }
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    final player = _playerRef;
    _playerRef = null;
    await player?.dispose();
  }

  @override
  void dispose() {
    // Cancel subscriptions synchronously
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    onSeekCallback = null;
    // Dispose player safely - catch errors since Flutter engine may already be shutting down
    try {
      _playerRef?.dispose();
    } catch (_) {
      // Ignore disposal errors during app shutdown
    }
    _playerRef = null;
    super.dispose();
  }
}

/// Riverpod provider for VideoPlayerNotifier
final videoPlayerNotifierProvider =
    StateNotifierProvider.autoDispose<VideoPlayerNotifier, VideoPlayerState>(
  (ref) => VideoPlayerNotifier(),
);

import 'dart:async';
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
    try {
      // Dispose previous player if any
      await _disposePlayer();

      final player = Player();
      final controller = VideoController(player);
      _playerRef = player;

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

      // Open the media
      await player.open(Media(videoUrl), play: false);
    } catch (e) {
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
    // Cancel subscriptions synchronously, dispose player in background
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _playerRef?.dispose();
    _playerRef = null;
    super.dispose();
  }
}

/// Riverpod provider for VideoPlayerNotifier
final videoPlayerNotifierProvider =
    StateNotifierProvider.autoDispose<VideoPlayerNotifier, VideoPlayerState>(
  (ref) => VideoPlayerNotifier(),
);

// FrontEnd/lib/core/design/editor_theme.dart
import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'base_theme.dart';

/// Editor-specific colours with no Material role.
///
/// Read via `Theme.of(context).extension<EditorTheme>()!`.
@immutable
class EditorTheme extends ThemeExtension<EditorTheme> {
  final Color videoStage;
  final Color timelineTrack;
  final Color timelineBlock;
  final Color timelineBlockSelected;
  final Color timelineBlockBorder;
  final Color playhead;
  final Color segmentActive;
  final Color segmentSelected;
  final Color editedMarker;
  final Color overlapMarker;
  final Color overlayScrim;

  const EditorTheme({
    required this.videoStage,
    required this.timelineTrack,
    required this.timelineBlock,
    required this.timelineBlockSelected,
    required this.timelineBlockBorder,
    required this.playhead,
    required this.segmentActive,
    required this.segmentSelected,
    required this.editedMarker,
    required this.overlapMarker,
    required this.overlayScrim,
  });

  static const EditorTheme light = EditorTheme(
    videoStage: AppPalette.videoStage,
    timelineTrack: AppPalette.surfaceContainerLow,
    timelineBlock: AppPalette.surfaceContainerLowest,
    timelineBlockSelected: AppPalette.tealSubtle,
    timelineBlockBorder: AppPalette.primary,
    playhead: AppPalette.error,
    segmentActive: AppPalette.tealSubtle,
    segmentSelected: AppPalette.tealSubtle,
    editedMarker: AppPalette.warning,
    overlapMarker: AppPalette.error,
    overlayScrim: Color(0xB3000000), // 70% black — PRODUCT_OVERVIEW §6.13
  );

  static const EditorTheme dark = EditorTheme(
    videoStage: AppPalette.videoStage,
    timelineTrack: AppPalette.surfaceContainerLowDark,
    timelineBlock: AppPalette.surfaceContainerHighDark,
    timelineBlockSelected: AppPalette.primaryContainerDark,
    timelineBlockBorder: AppPalette.primaryDark,
    playhead: AppPalette.errorDark,
    segmentActive: AppPalette.tealSubtleDark,
    segmentSelected: AppPalette.tealSubtleDark,
    editedMarker: AppPalette.warningDark,
    overlapMarker: AppPalette.errorDark,
    overlayScrim: Color(0xB3000000),
  );

  @override
  EditorTheme copyWith({
    Color? videoStage,
    Color? timelineTrack,
    Color? timelineBlock,
    Color? timelineBlockSelected,
    Color? timelineBlockBorder,
    Color? playhead,
    Color? segmentActive,
    Color? segmentSelected,
    Color? editedMarker,
    Color? overlapMarker,
    Color? overlayScrim,
  }) {
    return EditorTheme(
      videoStage: videoStage ?? this.videoStage,
      timelineTrack: timelineTrack ?? this.timelineTrack,
      timelineBlock: timelineBlock ?? this.timelineBlock,
      timelineBlockSelected:
          timelineBlockSelected ?? this.timelineBlockSelected,
      timelineBlockBorder: timelineBlockBorder ?? this.timelineBlockBorder,
      playhead: playhead ?? this.playhead,
      segmentActive: segmentActive ?? this.segmentActive,
      segmentSelected: segmentSelected ?? this.segmentSelected,
      editedMarker: editedMarker ?? this.editedMarker,
      overlapMarker: overlapMarker ?? this.overlapMarker,
      overlayScrim: overlayScrim ?? this.overlayScrim,
    );
  }

  @override
  EditorTheme lerp(ThemeExtension<EditorTheme>? other, double t) {
    if (other is! EditorTheme) return this;
    return EditorTheme(
      videoStage: Color.lerp(videoStage, other.videoStage, t)!,
      timelineTrack: Color.lerp(timelineTrack, other.timelineTrack, t)!,
      timelineBlock: Color.lerp(timelineBlock, other.timelineBlock, t)!,
      timelineBlockSelected:
          Color.lerp(timelineBlockSelected, other.timelineBlockSelected, t)!,
      timelineBlockBorder:
          Color.lerp(timelineBlockBorder, other.timelineBlockBorder, t)!,
      playhead: Color.lerp(playhead, other.playhead, t)!,
      segmentActive: Color.lerp(segmentActive, other.segmentActive, t)!,
      segmentSelected: Color.lerp(segmentSelected, other.segmentSelected, t)!,
      editedMarker: Color.lerp(editedMarker, other.editedMarker, t)!,
      overlapMarker: Color.lerp(overlapMarker, other.overlapMarker, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
    );
  }
}

/// The scoped theme the editor wraps itself in: the shared [buildBaseTheme]
/// base plus the editor-only [EditorTheme] extension.
///
/// Deliberately NOT applied app-wide: the un-redesigned screens still use
/// AppColors/AppTheme and are redesigned separately.
ThemeData buildEditorTheme(bool isDark) {
  return buildBaseTheme(isDark).copyWith(
    extensions: <ThemeExtension<dynamic>>[
      isDark ? EditorTheme.dark : EditorTheme.light,
    ],
  );
}

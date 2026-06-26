import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subtitle_project_model.dart';
import '../models/transcription_model.dart';
import '../services/subtitle_service.dart';

/// Represents an undoable/redoable editor action
class EditorAction {
  final EditorActionType type;
  final List<EditableSegment> previousSegments;
  final int? selectedIndex;

  EditorAction({
    required this.type,
    required this.previousSegments,
    this.selectedIndex,
  });
}

enum EditorActionType {
  editText,
  editTiming,
  addSegment,
  deleteSegment,
  fixOverlaps,
  bulkEdit,
}

/// Editor state
class EditorState {
  final SubtitleProject? project;
  final int? selectedSegmentIndex;
  final bool isLoading;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final String? error;
  final String searchQuery;
  final List<int> searchResults;
  final List<EditorAction> undoStack;
  final List<EditorAction> redoStack;
  final DateTime? lastAutoSave;

  EditorState({
    this.project,
    this.selectedSegmentIndex,
    this.isLoading = false,
    this.isSaving = false,
    this.hasUnsavedChanges = false,
    this.error,
    this.searchQuery = '',
    this.searchResults = const [],
    this.undoStack = const [],
    this.redoStack = const [],
    this.lastAutoSave,
  });

  List<EditableSegment> get segments => project?.segments ?? [];

  EditableSegment? get selectedSegment {
    if (selectedSegmentIndex != null &&
        selectedSegmentIndex! >= 0 &&
        selectedSegmentIndex! < segments.length) {
      return segments[selectedSegmentIndex!];
    }
    return null;
  }

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  EditorState copyWith({
    SubtitleProject? project,
    int? Function()? selectedSegmentIndex,
    bool? isLoading,
    bool? isSaving,
    bool? hasUnsavedChanges,
    String? Function()? error,
    String? searchQuery,
    List<int>? searchResults,
    List<EditorAction>? undoStack,
    List<EditorAction>? redoStack,
    DateTime? lastAutoSave,
  }) {
    return EditorState(
      project: project ?? this.project,
      selectedSegmentIndex: selectedSegmentIndex != null
          ? selectedSegmentIndex()
          : this.selectedSegmentIndex,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      error: error != null ? error() : this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      lastAutoSave: lastAutoSave ?? this.lastAutoSave,
    );
  }

  factory EditorState.initial() => EditorState();
}

/// The main editor state notifier
class EditorNotifier extends StateNotifier<EditorState> {
  final SubtitleService _subtitleService;
  Timer? _autoSaveTimer;

  static const int maxUndoStack = 50;
  static const Duration autoSaveInterval = Duration(seconds: 30);

  EditorNotifier(this._subtitleService) : super(EditorState.initial());

  // ===== Lifecycle =====

  /// Load a project from transcription data
  Future<void> loadProject(
    String fileId, [
    TranscriptionModel? transcription,
  ]) async {
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final project = await _subtitleService.createProject(fileId);

      state = state.copyWith(
        project: project,
        isLoading: false,
        hasUnsavedChanges: false,
        undoStack: [],
        redoStack: [],
      );

      _startAutoSave();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => 'Failed to load project: $e',
      );
    }
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) {
      if (state.hasUnsavedChanges && !state.isSaving) {
        save();
      }
    });
  }

  // ===== Segment Selection =====

  void selectSegment(int index) {
    if (index >= 0 && index < state.segments.length) {
      state = state.copyWith(selectedSegmentIndex: () => index);
    }
  }

  void clearSelection() {
    state = state.copyWith(selectedSegmentIndex: () => null);
  }

  // ===== Editing Operations =====

  void _pushUndo(EditorActionType type) {
    final previous = state.segments
        .map((s) => s.copyWith())
        .toList();
    var stack = [...state.undoStack, EditorAction(
      type: type,
      previousSegments: previous,
      selectedIndex: state.selectedSegmentIndex,
    )];
    // Cap at max
    if (stack.length > maxUndoStack) {
      stack = stack.sublist(stack.length - maxUndoStack);
    }
    state = state.copyWith(
      undoStack: stack,
      redoStack: [], // Clear redo on new action
    );
  }

  void updateSegmentText(int index, {String? romanUrduText, String? urduText}) {
    if (index < 0 || index >= state.segments.length) return;

    _pushUndo(EditorActionType.editText);

    final segment = state.segments[index];
    if (romanUrduText != null) segment.romanUrduText = romanUrduText;
    if (urduText != null) segment.urduText = urduText;
    segment.isEdited = true;

    state = state.copyWith(hasUnsavedChanges: true);
  }

  void updateSegmentTiming(int index, double start, double end) {
    if (index < 0 || index >= state.segments.length) return;

    _pushUndo(EditorActionType.editTiming);

    final segment = state.segments[index];
    segment.start = start;
    segment.end = end;
    segment.isEdited = true;

    state = state.copyWith(hasUnsavedChanges: true);
  }

  Future<void> addSegment(int afterIndex) async {
    if (state.project == null) return;

    final segments = state.segments;
    if (afterIndex < 0 || afterIndex >= segments.length) return;

    _pushUndo(EditorActionType.addSegment);

    final prevSegment = segments[afterIndex];
    final nextStart = prevSegment.end + 0.1;

    try {
      await _subtitleService.addSegment(
        state.project!.subtitleId,
        afterSegmentId: prevSegment.id,
        start: nextStart,
        end: nextStart + 2.0,
        romanUrduText: '',
        urduText: '',
      );

      // Refresh project from server (IDs resequenced)
      final updated = await _subtitleService.getProject(
        state.project!.subtitleId,
      );
      state = state.copyWith(
        project: updated,
        hasUnsavedChanges: false,
        selectedSegmentIndex: () => afterIndex + 1,
      );
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to add segment: $e');
    }
  }

  Future<void> deleteSegment(int index) async {
    if (state.project == null) return;

    final segments = state.segments;
    if (index < 0 || index >= segments.length) return;

    _pushUndo(EditorActionType.deleteSegment);

    try {
      await _subtitleService.deleteSegment(
        state.project!.subtitleId,
        segments[index].id,
      );

      // Refresh project from server
      final updated = await _subtitleService.getProject(
        state.project!.subtitleId,
      );

      int? newSelection;
      if (updated.segments.isNotEmpty) {
        newSelection = index >= updated.segments.length
            ? updated.segments.length - 1
            : index;
      }

      state = state.copyWith(
        project: updated,
        hasUnsavedChanges: false,
        selectedSegmentIndex: () => newSelection,
      );
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to delete segment: $e');
    }
  }

  // ===== Undo / Redo =====

  void undo() {
    if (!state.canUndo) return;

    final action = state.undoStack.last;
    final currentSegments = state.segments
        .map((s) => s.copyWith())
        .toList();

    // Push current state to redo
    final redoStack = [
      ...state.redoStack,
      EditorAction(
        type: action.type,
        previousSegments: currentSegments,
        selectedIndex: state.selectedSegmentIndex,
      ),
    ];

    // Restore previous segments
    final project = state.project;
    if (project == null) return;

    final restored = SubtitleProject(
      subtitleId: project.subtitleId,
      fileId: project.fileId,
      projectName: project.projectName,
      originalFilename: project.originalFilename,
      isVideo: project.isVideo,
      segments: action.previousSegments,
      segmentCount: action.previousSegments.length,
      fileDuration: project.fileDuration,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
    );

    state = state.copyWith(
      project: restored,
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: redoStack,
      selectedSegmentIndex: () => action.selectedIndex,
      hasUnsavedChanges: true,
    );
  }

  void redo() {
    if (!state.canRedo) return;

    final action = state.redoStack.last;
    final currentSegments = state.segments
        .map((s) => s.copyWith())
        .toList();

    // Push current state to undo
    final undoStack = [
      ...state.undoStack,
      EditorAction(
        type: action.type,
        previousSegments: currentSegments,
        selectedIndex: state.selectedSegmentIndex,
      ),
    ];

    final project = state.project;
    if (project == null) return;

    final restored = SubtitleProject(
      subtitleId: project.subtitleId,
      fileId: project.fileId,
      projectName: project.projectName,
      originalFilename: project.originalFilename,
      isVideo: project.isVideo,
      segments: action.previousSegments,
      segmentCount: action.previousSegments.length,
      fileDuration: project.fileDuration,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
    );

    state = state.copyWith(
      project: restored,
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
      undoStack: undoStack,
      selectedSegmentIndex: () => action.selectedIndex,
      hasUnsavedChanges: true,
    );
  }

  // ===== Search =====

  void search(String query) {
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = <int>[];
    for (int i = 0; i < state.segments.length; i++) {
      final seg = state.segments[i];
      if (seg.romanUrduText.toLowerCase().contains(lowerQuery) ||
          seg.urduText.toLowerCase().contains(lowerQuery)) {
        results.add(i);
      }
    }

    state = state.copyWith(
      searchQuery: query,
      searchResults: results,
    );
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      searchResults: [],
    );
  }

  // ===== Auto-fix =====

  Future<void> fixTimingOverlaps() async {
    if (state.project == null) return;

    _pushUndo(EditorActionType.fixOverlaps);

    try {
      final fixedSegments = await _subtitleService.fixOverlaps(
        state.project!.subtitleId,
      );

      final project = state.project!;
      final updated = SubtitleProject(
        subtitleId: project.subtitleId,
        fileId: project.fileId,
        projectName: project.projectName,
        originalFilename: project.originalFilename,
        isVideo: project.isVideo,
        segments: fixedSegments,
        segmentCount: fixedSegments.length,
        fileDuration: project.fileDuration,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
      );

      state = state.copyWith(
        project: updated,
        hasUnsavedChanges: false,
      );
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to fix overlaps: $e');
    }
  }

  // ===== Save & Export =====

  Future<void> save() async {
    if (state.project == null || state.isSaving) return;

    state = state.copyWith(isSaving: true);

    try {
      await _subtitleService.bulkUpdate(
        state.project!.subtitleId,
        state.segments,
      );

      state = state.copyWith(
        isSaving: false,
        hasUnsavedChanges: false,
        lastAutoSave: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: () => 'Failed to save: $e',
      );
    }
  }

  Future<Map<String, String>?> export(String format) async {
    if (state.project == null) return null;

    // Save first if there are unsaved changes
    if (state.hasUnsavedChanges) await save();

    try {
      return await _subtitleService.exportSubtitles(
        state.project!.subtitleId,
        format,
      );
    } catch (e) {
      state = state.copyWith(error: () => 'Export failed: $e');
      return null;
    }
  }

  /// Render and download the project's video with captions.
  ///
  /// [mode] is `hardsub` or `softsub`. Returns the bytes + filename, or null
  /// on failure (error is recorded in state).
  Future<({List<int> bytes, String filename})?> exportVideo(String mode) async {
    if (state.project == null) return null;

    // Save first so the rendered video reflects the latest edits.
    if (state.hasUnsavedChanges) await save();

    try {
      return await _subtitleService.downloadVideoWithCaptions(
        state.project!.subtitleId,
        mode,
      );
    } catch (e) {
      state = state.copyWith(error: () => 'Video export failed: $e');
      return null;
    }
  }

  // ===== Playback Sync =====

  /// Find the segment index at the given playback time using binary search
  int? getSegmentAtTime(double seconds) {
    final segments = state.segments;
    if (segments.isEmpty) return null;

    int low = 0;
    int high = segments.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final seg = segments[mid];

      if (seconds >= seg.start && seconds <= seg.end) {
        return mid;
      } else if (seconds < seg.start) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return null;
  }

  void clearError() {
    state = state.copyWith(error: () => null);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for EditorNotifier
final editorNotifierProvider =
    StateNotifierProvider.autoDispose<EditorNotifier, EditorState>((ref) {
  final subtitleService = ref.watch(subtitleServiceProvider);
  return EditorNotifier(subtitleService);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../providers/subtitle_editor_provider.dart';
import '../../providers/video_player_provider.dart';
import 'segment_tile.dart';

/// Center panel: scrollable list of subtitle segments with search
class SubtitleListPanel extends ConsumerStatefulWidget {
  const SubtitleListPanel({super.key});

  @override
  ConsumerState<SubtitleListPanel> createState() => _SubtitleListPanelState();
}

class _SubtitleListPanelState extends ConsumerState<SubtitleListPanel> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int? _lastActiveSegment;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final offset = (index * SegmentTile.height).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorNotifierProvider);
    final editorNotifier = ref.read(editorNotifierProvider.notifier);
    final playerState = ref.watch(videoPlayerNotifierProvider);
    final playerNotifier = ref.read(videoPlayerNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final segments = editorState.segments;

    // Auto-scroll to active segment during playback
    final activeSegment = editorNotifier.getSegmentAtTime(
      playerState.positionSeconds,
    );
    if (activeSegment != null && activeSegment != _lastActiveSegment) {
      _lastActiveSegment = activeSegment;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(activeSegment);
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        border: Border(
          right: BorderSide(color: AppColors.getBorder(isDark), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with search
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceVariant(isDark),
              border: Border(
                bottom: BorderSide(color: AppColors.getBorder(isDark)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.subtitles_rounded,
                      size: AppSizes.iconSm,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      'Segments (${segments.length})',
                      style: TextStyle(
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                // Search bar
                SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search subtitles...',
                      hintStyle: TextStyle(
                        fontSize: AppSizes.fontXs,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                editorNotifier.clearSearch();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(isDark),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(isDark),
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.getSurface(isDark),
                    ),
                    onChanged: (value) => editorNotifier.search(value),
                  ),
                ),
              ],
            ),
          ),

          // Segment list
          Expanded(
            child: segments.isEmpty
                ? Center(
                    child: Text(
                      'No segments',
                      style: TextStyle(
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: segments.length,
                    itemBuilder: (context, index) {
                      final next = index + 1 < segments.length
                          ? segments[index + 1]
                          : null;
                      return SegmentTile(
                        segment: segments[index],
                        index: index,
                        isSelected: editorState.selectedSegmentIndex == index,
                        isActive: activeSegment == index,
                        matchesSearch: editorState.searchResults.contains(
                          index,
                        ),
                        hasOverlap: segments[index].overlapsNext(next),
                        onTap: () {
                          editorNotifier.selectSegment(index);
                          // Seek video to segment start
                          playerNotifier.seekToSeconds(segments[index].start);
                        },
                        onDelete: () => editorNotifier.deleteSegment(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

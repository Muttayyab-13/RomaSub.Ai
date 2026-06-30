import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/nav_provider.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/projects/projects_screen.dart';
import '../../screens/exports/exports_screen.dart';
import '../../screens/feedback/feedback_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../sidebar/sidebar.dart';

/// App shell for the five top-level destinations.
///
/// A persistent [Sidebar] plus an [IndexedStack] of the tab screens. The stack
/// keeps every tab alive, so scroll position, search text, and form state are
/// preserved when switching tabs (fixes the old `replace()`-based navigation
/// that destroyed both the back stack and per-screen state).
///
/// Editor and realtime-viewer are NOT tabs — they are pushed full-screen over
/// this shell. Their embedded sidebar uses `selectedIndexOverride: -1` and a
/// `popUntil(isFirst)` tap handler to return here with the chosen tab selected.
class MainShell extends ConsumerStatefulWidget {
  /// Tab to open on first mount. Normal entry uses 0 (dashboard); a non-zero
  /// value supports deep-linking into a specific tab.
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Write the provider exactly once for a deep-linked initial tab. build()
    // only ever watches it, so there is no rebuild fight. Deferred to a
    // post-frame callback to avoid mutating a provider mid-build.
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(navIndexProvider.notifier).state = widget.initialIndex;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexProvider);

    return PopScope(
      // Allow the system back to pop only from the dashboard tab; on any other
      // tab, back returns to the dashboard tab instead of exiting the app.
      canPop: index == AppTab.dashboard.index,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(navIndexProvider.notifier).state = AppTab.dashboard.index;
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            const Sidebar(),
            Expanded(
              child: IndexedStack(
                // expand gives the Expanded-in-Column tab screens (projects,
                // exports, feedback) a tight, bounded height to lay out in.
                sizing: StackFit.expand,
                index: index,
                children: const [
                  DashboardScreen(),
                  ProjectsScreen(),
                  ExportsScreen(),
                  FeedbackScreen(),
                  SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

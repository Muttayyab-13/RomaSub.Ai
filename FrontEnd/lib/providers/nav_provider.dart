import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level navigation tabs hosted by `MainShell`'s IndexedStack.
///
/// The order here is the single source of truth: the IndexedStack `children`
/// list, the Sidebar menu items, and the shell's back-button handling all index
/// into this enum. Keep them in sync.
enum AppTab { dashboard, projects, exports, feedback, settings }

/// Currently-selected shell tab index.
///
/// Driven by the Sidebar (and the dashboard profile shortcut); read by the
/// shell's `IndexedStack` and the Sidebar's active-item highlight. A plain
/// `StateProvider<int>` matches the codebase's lightweight provider style.
final navIndexProvider = StateProvider<int>((ref) => 0);

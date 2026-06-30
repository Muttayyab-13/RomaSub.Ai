import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).isDark;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return IconButton(
      onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
      icon: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(isDark),
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

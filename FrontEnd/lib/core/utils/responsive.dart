import 'package:flutter/widgets.dart';
import '../constants/app_sizes.dart';

/// Responsive helpers keyed off the logical screen width.
///
/// Uses [MediaQuery.sizeOf] (not `MediaQuery.of(context).size`) so widgets only
/// rebuild when the size actually changes, not on every MediaQuery update.
extension Responsive on BuildContext {
  /// Current logical screen width.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// < 600 — phone-sized window.
  bool get isMobile => screenWidth < AppSizes.breakpointMobile;

  /// < 1024 — phone or narrow tablet/desktop window (sidebar collapses here).
  bool get isTablet => screenWidth < AppSizes.breakpointTablet;

  /// >= 1024 — full desktop width (expanded labeled sidebar).
  bool get isDesktop => screenWidth >= AppSizes.breakpointTablet;
}

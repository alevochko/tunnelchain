import 'package:flutter/material.dart';

/// Spacing tokens from design-system/MASTER.md.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 18.0;
  static const xxl = 22.0;
  static const xxxl = 24.0;

  static const sidebarWidth = 236.0;
  static const sidebarWidthCollapsed = 52.0;
  static const sidebarPaddingH = 10.0;
  static const sidebarPaddingTop = 14.0;

  static const screenHeaderPaddingV = 18.0;
  static const screenHeaderPaddingH = 26.0;
  static const screenBodyPaddingBottom = 36.0;

  static const cardPadding = 22.0;
  static const cardRadius = 12.0;
  static const heroCardRadius = 16.0;
  static const buttonRadius = 8.0;

  /// Desktop buttons — matches design reference (+ New profile: 12px / 5×12 pad / 8r).
  static const buttonHeight = 32.0;
  static const buttonPaddingH = 12.0;
  static const buttonIconSize = 14.0;

  /// Segmented controls stay compact.
  static const segmentedControlHeight = 32.0;

  /// Sidebar nav rows and larger tap targets.
  static const navItemHeight = 36.0;
}

abstract final class AppRadii {
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const hero = 16.0;
  static const pill = 20.0;
}

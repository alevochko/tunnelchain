import 'package:flutter/material.dart';

/// Design tokens from [design-system/MASTER.md].
abstract final class AppColors {
  // Dark
  static const darkBackground = Color(0xFF0D1117);
  static const darkSurface = Color(0xFF161B22);
  static const darkSurface2 = Color(0xFF1C2128);
  static const darkSurfaceElevated = Color(0xFF21262D);
  static const darkBorder = Color(0xFF30363D);
  static const darkTextPrimary = Color(0xFFE6EDF3);
  static const darkTextSecondary = Color(0xFF8B949E);

  // Light
  static const lightBackground = Color(0xFFF6F8FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFF0F3F6);
  static const lightBorder = Color(0xFFD0D7DE);
  static const lightTextPrimary = Color(0xFF1F2328);
  static const lightTextSecondary = Color(0xFF656D76);

  // Shared
  static const accent = Color(0xFF388BFD);
  static const accentHover = Color(0xFF58A6FF);
  static const accentLight = Color(0xFF0969DA);
  static const running = Color(0xFF3FB950);
  static const runningLight = Color(0xFF1F883D);
  static const degraded = Color(0xFFD29922);
  static const degradedLight = Color(0xFF9A6700);
  static const failed = Color(0xFFF85149);
  static const failedLight = Color(0xFFCF222E);
  static const stopped = Color(0xFF8B949E);

  static Color accentBg(Brightness b) => accent.withValues(alpha: b == Brightness.dark ? 0.14 : 0.10);
  static Color runningBg(Brightness b) => (b == Brightness.dark ? running : runningLight).withValues(alpha: b == Brightness.dark ? 0.14 : 0.10);
  static Color warningBg(Brightness b) => (b == Brightness.dark ? degraded : degradedLight).withValues(alpha: b == Brightness.dark ? 0.14 : 0.10);
  static Color errorBg(Brightness b) => (b == Brightness.dark ? failed : failedLight).withValues(alpha: b == Brightness.dark ? 0.13 : 0.09);
}

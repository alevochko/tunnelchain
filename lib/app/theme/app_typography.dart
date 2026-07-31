import 'package:flutter/material.dart';

/// Typography from design-system/MASTER.md.
abstract final class AppTypography {
  static const String monoFamily = 'Menlo';

  static const screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static const screenSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const brandTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const navItem = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  static const helperBadge = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Section labels: ADD PROXY, SAVED NODES, etc.
  static const sectionHeader = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0.7,
    fontFamily: monoFamily,
  );

  static const overline = sectionHeader;

  static const cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const body14 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const body135 = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const body125 = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const button = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0.1,
  );

  static const buttonSecondary = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0.1,
  );

  static const mono145 = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFamily: monoFamily,
  );

  static const mono135 = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.6,
    fontFamily: monoFamily,
  );

  static const mono125 = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
    fontFamily: monoFamily,
  );

  static const mono12 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFamily: monoFamily,
  );

  static const linkMono = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFamily: monoFamily,
  );

  static const heroLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: -0.1,
  );

  static const statusPill = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1,
  );

  // Legacy aliases used by theme bootstrap.
  static const display = screenTitle;
  static const title = cardTitle;
  static const body = body14;
  static const caption = body125;
  static const mono = mono125;
}

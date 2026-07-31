import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';

class SectionOverline extends StatelessWidget {
  const SectionOverline(this.label, {super.key, this.bottom = 16});

  final String label;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.sectionHeader.copyWith(
          color: AppThemeTokens.of(context).textSecondary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurfaceElevated;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primary = isDark ? AppColors.accent : AppColors.accentLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: surface,
      onSecondary: textPrimary,
      error: isDark ? AppColors.failed : AppColors.failedLight,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      tertiary: textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      extensions: [
        AppThemeTokens(
          surface2: surface2,
          textSecondary: textSecondary,
          accentBg: AppColors.accentBg(brightness),
          runningBg: AppColors.runningBg(brightness),
          warningBg: AppColors.warningBg(brightness),
          errorBg: AppColors.errorBg(brightness),
        ),
      ],
      textTheme: TextTheme(
        headlineSmall: AppTypography.screenTitle.copyWith(color: textPrimary),
        titleMedium: AppTypography.cardTitle.copyWith(color: textPrimary),
        titleSmall: AppTypography.cardTitle.copyWith(color: textPrimary),
        bodyMedium: AppTypography.body14.copyWith(color: textPrimary),
        bodySmall: AppTypography.body125.copyWith(color: textSecondary),
        labelLarge: AppTypography.button.copyWith(color: textPrimary),
        labelSmall: AppTypography.sectionHeader.copyWith(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: border,
        dividerHeight: 1,
        indicatorColor: primary,
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        labelStyle: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.body14,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        mouseCursor: WidgetStateMouseCursor.clickable,
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: WidgetStateMouseCursor.clickable,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: border),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: actionMouseCursor(
          FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, AppSpacing.buttonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonPaddingH,
            ),
            iconSize: AppSpacing.buttonIconSize,
            textStyle: AppTypography.button.copyWith(color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            elevation: 0,
            visualDensity: VisualDensity.standard,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: actionMouseCursor(
          OutlinedButton.styleFrom(
            backgroundColor: surface2,
            foregroundColor: textPrimary,
            minimumSize: const Size(0, AppSpacing.buttonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonPaddingH,
            ),
            iconSize: AppSpacing.buttonIconSize,
            textStyle: AppTypography.button.copyWith(color: textPrimary),
            side: BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            elevation: 0,
            visualDensity: VisualDensity.standard,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: actionMouseCursor(
          TextButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(0, AppSpacing.buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            textStyle: AppTypography.buttonSecondary.copyWith(color: primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            visualDensity: VisualDensity.standard,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: actionMouseCursor(
          IconButton.styleFrom(
            minimumSize: const Size(AppSpacing.buttonHeight, AppSpacing.buttonHeight),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: border),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: AppTypography.body125.copyWith(color: textSecondary),
      ),
    );
  }
}

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.surface2,
    required this.textSecondary,
    required this.accentBg,
    required this.runningBg,
    required this.warningBg,
    required this.errorBg,
  });

  final Color surface2;
  final Color textSecondary;
  final Color accentBg;
  final Color runningBg;
  final Color warningBg;
  final Color errorBg;

  static AppThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<AppThemeTokens>()!;
  }

  @override
  AppThemeTokens copyWith({
    Color? surface2,
    Color? textSecondary,
    Color? accentBg,
    Color? runningBg,
    Color? warningBg,
    Color? errorBg,
  }) {
    return AppThemeTokens(
      surface2: surface2 ?? this.surface2,
      textSecondary: textSecondary ?? this.textSecondary,
      accentBg: accentBg ?? this.accentBg,
      runningBg: runningBg ?? this.runningBg,
      warningBg: warningBg ?? this.warningBg,
      errorBg: errorBg ?? this.errorBg,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      surface2: Color.lerp(surface2, other.surface2, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accentBg: Color.lerp(accentBg, other.accentBg, t)!,
      runningBg: Color.lerp(runningBg, other.runningBg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
    );
  }
}

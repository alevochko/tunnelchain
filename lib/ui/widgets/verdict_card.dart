import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';

enum VerdictTone { warning, error, success }

/// Alert / verdict banner from design-system/MASTER.md.
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    required this.title,
    required this.body,
    super.key,
    this.monoDetail,
    this.actionLabel,
    this.onAction,
    this.tone = VerdictTone.warning,
    this.trailing,
    this.leading,
  });

  final String title;
  final String body;
  final String? monoDetail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VerdictTone tone;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final accent = switch (tone) {
      VerdictTone.warning =>
        isDark ? AppColors.degraded : AppColors.degradedLight,
      VerdictTone.error => isDark ? AppColors.failed : AppColors.failedLight,
      VerdictTone.success => isDark ? AppColors.running : AppColors.runningLight,
    };
    final bg = switch (tone) {
      VerdictTone.warning => AppColors.warningBg(brightness),
      VerdictTone.error => AppColors.errorBg(brightness),
      VerdictTone.success => AppColors.runningBg(brightness),
    };
    final bodyColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Material(
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 20, 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(color: accent),
                  ),
                  if (monoDetail != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      monoDetail!,
                      style: AppTypography.mono135.copyWith(color: bodyColor),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: AppTypography.body14.copyWith(
                      color: bodyColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 18),
              trailing!,
            ] else if (actionLabel != null) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onAction,
                style: actionMouseCursor(
                  OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: accent.withValues(alpha: 0.65)),
                    textStyle: AppTypography.button.copyWith(color: accent),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WarningIcon extends StatelessWidget {
  const WarningIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _WarningIconPainter(),
    );
  }
}

class ErrorIcon extends StatelessWidget {
  const ErrorIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _ErrorIconPainter(),
    );
  }
}

class _WarningIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()
      ..color = AppColors.degraded
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(9 * s, 2.5 * s)
        ..lineTo(16.5 * s, 15.5 * s)
        ..lineTo(1.5 * s, 15.5 * s)
        ..close(),
      paint,
    );
    canvas.drawLine(Offset(9 * s, 7 * s), Offset(9 * s, 10.4 * s), paint..strokeWidth = 1.6 * s);
    canvas.drawCircle(Offset(9 * s, 12.7 * s), 0.9 * s, Paint()..color = AppColors.degraded);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()
      ..color = AppColors.failed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s;
    canvas.drawCircle(Offset(9 * s, 9 * s), 7 * s, paint);
    canvas.drawLine(Offset(6.5 * s, 6.5 * s), Offset(11.5 * s, 11.5 * s), paint..strokeWidth = 1.6 * s);
    canvas.drawLine(Offset(11.5 * s, 6.5 * s), Offset(6.5 * s, 11.5 * s), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

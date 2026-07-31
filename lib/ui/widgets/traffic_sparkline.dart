import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/services/clash_api_client.dart';

class TrafficSparkline extends StatelessWidget {
  const TrafficSparkline({
    required this.history,
    required this.live,
    this.height = 60,
    this.emptyLabel,
    super.key,
  });

  final List<TrafficSample> history;
  final bool live;
  final double height;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uploadColor = isDark ? AppColors.running : AppColors.runningLight;
    final downloadColor = isDark ? AppColors.accent : AppColors.accentLight;
    final upload = history.map((s) => s.uploadBps).toList();
    final download = history.map((s) => s.downloadBps).toList();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: history.isEmpty
          ? Center(
              child: Text(
                emptyLabel ??
                    (live ? 'Waiting for samples…' : 'Connect to see live traffic'),
                style: AppTypography.mono12.copyWith(color: secondary),
              ),
            )
          : CustomPaint(
              painter: TrafficSparklinePainter(
                up: _seriesPoints(upload),
                down: _seriesPoints(download),
                uploadColor: uploadColor,
                downloadColor: downloadColor,
              ),
            ),
    );
  }

  static List<Offset> _seriesPoints(List<int> values) {
    if (values.isEmpty) return const [];
    final maxVal = values.fold<int>(1, (a, b) => a > b ? a : b);
    const width = 400.0;
    const height = 60.0;
    final step = values.length <= 1 ? 0.0 : width / (values.length - 1);

    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          step * i,
          height - 2 - (values[i] / maxVal) * (height - 6),
        ),
    ];
  }
}

class TrafficSparklinePainter extends CustomPainter {
  const TrafficSparklinePainter({
    required this.up,
    required this.down,
    this.uploadColor = AppColors.running,
    this.downloadColor = AppColors.accent,
    this.filled = false,
  });

  final List<Offset> up;
  final List<Offset> down;
  final Color uploadColor;
  final Color downloadColor;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    if (up.isEmpty && down.isEmpty) return;

    final sx = size.width / 400;
    final sy = size.height / 60;

    void draw(List<Offset> pts, Color color) {
      if (pts.length < 2) {
        if (pts.length == 1) {
          canvas.drawCircle(
            Offset(pts.first.dx * sx, pts.first.dy * sy),
            2,
            Paint()..color = color,
          );
        }
        return;
      }
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final p = Offset(pts[i].dx * sx, pts[i].dy * sy);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      if (filled) {
        final fill = Path.from(path)
          ..lineTo(pts.last.dx * sx, size.height)
          ..lineTo(pts.first.dx * sx, size.height)
          ..close();
        canvas.drawPath(
          fill,
          Paint()..color = color.withValues(alpha: 0.18),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    draw(down, downloadColor);
    draw(up, uploadColor);
  }

  @override
  bool shouldRepaint(covariant TrafficSparklinePainter oldDelegate) =>
      oldDelegate.up != up ||
      oldDelegate.down != down ||
      oldDelegate.filled != filled;
}

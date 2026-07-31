import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';

/// Chain-link logo from design-system/MASTER.md.
class TunnelChainLogo extends StatelessWidget {
  const TunnelChainLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TunnelChainLogoPainter(),
    );
  }
}

class _TunnelChainLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20;
    final path = Path()
      ..moveTo(3 * scale, 6.5 * scale)
      ..lineTo(8.5 * scale, 6.5 * scale)
      ..cubicTo(
        10 * scale,
        6.5 * scale,
        11.5 * scale,
        8 * scale,
        11.5 * scale,
        9.5 * scale,
      )
      ..lineTo(11.5 * scale, 10.5 * scale)
      ..cubicTo(
        11.5 * scale,
        12 * scale,
        13 * scale,
        13.5 * scale,
        14.5 * scale,
        13.5 * scale,
      )
      ..lineTo(17 * scale, 13.5 * scale);

    final stroke = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, stroke);
    canvas.drawCircle(
      Offset(3 * scale, 6.5 * scale),
      2 * scale,
      Paint()..color = AppColors.running,
    );
    canvas.drawCircle(
      Offset(17 * scale, 13.5 * scale),
      2 * scale,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

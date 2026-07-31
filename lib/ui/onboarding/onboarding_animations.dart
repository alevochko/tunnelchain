import 'package:flutter/material.dart';

/// CSS `ease` — cubic-bezier(0.25, 0.1, 0.25, 1.0).
const kTcEase = Cubic(0.25, 0.1, 0.25, 1.0);

/// CSS: `tcIn` — opacity 0→1, optional scale .97→1, .35s ease.
class TcInAnimation extends StatefulWidget {
  const TcInAnimation({required this.child, super.key, this.scale = false});

  final Widget child;
  final bool scale;

  @override
  State<TcInAnimation> createState() => _TcInAnimationState();
}

class _TcInAnimationState extends State<TcInAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = kTcEase.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: widget.scale
              ? Transform.scale(
                  scale: 0.97 + (0.03 * t),
                  alignment: Alignment.center,
                  child: child,
                )
              : child,
        );
      },
      child: widget.child,
    );
  }
}

/// CSS: `tcUp` — opacity 0→1, translateY(10px)→0, .45s ease + optional delay.
class TcUpAnimation extends StatefulWidget {
  const TcUpAnimation({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<TcUpAnimation> createState() => _TcUpAnimationState();
}

class _TcUpAnimationState extends State<TcUpAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = kTcEase.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// CSS: `tcDash` — background-position 0 → -28px, linear infinite.
class TcDashLine extends StatelessWidget {
  const TcDashLine({
    required this.animation,
    required this.color,
    super.key,
  });

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final offset = (animation.value * 28) % 28;
          return CustomPaint(
            painter: _DashPainter(color: color, offset: offset),
            child: const SizedBox(height: 2, width: double.infinity),
          );
        },
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color, required this.offset});

  final Color color;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dash = 8.0;
    const gap = 6.0;
    const period = dash + gap;
    var x = -offset;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dash, size.height / 2),
        paint,
      );
      x += period;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.color != color;
  }
}

/// CSS: `tcPulse` — 0%/100% opacity .35 scale 1; 50% opacity .9 scale 1.06.
class TcPulseRing extends StatefulWidget {
  const TcPulseRing({required this.child, super.key, this.color});

  final Widget child;
  final Color? color;

  @override
  State<TcPulseRing> createState() => _TcPulseRingState();
}

class _TcPulseRingState extends State<TcPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _pulseT(double value) {
    // 0 → 0.5 → 1 maps to CSS keyframe stops with ease-in-out feel.
    if (value <= 0.5) {
      return Curves.easeInOut.transform(value * 2);
    }
    return Curves.easeInOut.transform((1 - value) * 2);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF3FB950);
    return RepaintBoundary(
      child: SizedBox(
        width: 148,
        height: 148,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final peak = _pulseT(_controller.value);
                final opacity = 0.35 + (0.55 * peak);
                final scale = 1 + (0.06 * peak);
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                );
              },
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

/// Swaps onboarding step previews — enter animation runs via [TcInAnimation].
class OnboardingStepTransition extends StatelessWidget {
  const OnboardingStepTransition({
    required this.step,
    required this.child,
    super.key,
  });

  final int step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(step),
      child: child,
    );
  }
}

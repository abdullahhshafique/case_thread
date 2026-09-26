import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Ambient atmosphere (v3 §2) — one shared decorative layer behind the
/// whole console: a faint 54px shell grid, a slowly rotating conic
/// aurora, and two breathing glow orbs. Pointer-transparent; disabled
/// under `prefers-reduced-motion` (v3 §12).
class AmbientAtmosphere extends StatefulWidget {
  const AmbientAtmosphere({super.key});

  @override
  State<AmbientAtmosphere> createState() => _AmbientAtmosphereState();
}

class _AmbientAtmosphereState extends State<AmbientAtmosphere>
    with SingleTickerProviderStateMixin {
  // Breathing glow orbs (14 s alternate, v3 §2).
  late final AnimationController _orbs = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _orbs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return const SizedBox.shrink();

    // RepaintBoundary isolates the constant atmosphere animation so the
    // console content never repaints on its ticks (web perf).
    return RepaintBoundary(
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              const _ShellGrid(),
              const _Aurora(),
              AnimatedBuilder(
                animation: _orbs,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_orbs.value);
                  return Stack(
                    children: [
                      Positioned(
                        left: -60,
                        top: -260,
                        child: _GlowOrb(
                          size: 560 + 90 * t,
                          color: AppColors.heroBlue,
                        ),
                      ),
                      Positioned(
                        right: -200,
                        top: 120,
                        child: _GlowOrb(
                          size: 480 + 70 * (1 - t),
                          color: AppColors.v3DeepViolet,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellGrid extends StatelessWidget {
  const _ShellGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cell = 54.0;
        final cols = (constraints.maxWidth / cell).ceil() + 1;
        final rows = (constraints.maxHeight / cell).ceil() + 1;
        final linePaint = Paint()
          ..color = AppColors.brandTeal.withValues(alpha: 0.04)
          ..strokeWidth = 1;
        return RepaintBoundary(
          // Static layer — never needs to repaint once laid out.
          child: CustomPaint(
            size: constraints.biggest,
            painter: _GridPainter(linePaint, cell, cols, rows),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.paint_, this.cell, this.cols, this.rows);

  final Paint paint_;
  final double cell;
  final int cols;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < cols; i++) {
      canvas.drawLine(
        Offset(i * cell, 0),
        Offset(i * cell, size.height),
        paint_,
      );
    }
    for (var j = 0; j < rows; j++) {
      canvas.drawLine(
        Offset(0, j * cell),
        Offset(size.width, j * cell),
        paint_,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols || old.rows != rows || old.cell != cell;
}

class _Aurora extends StatelessWidget {
  const _Aurora();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment(0.02, -0.34),
      child: _RotatingAurora(),
    );
  }
}

class _RotatingAurora extends StatefulWidget {
  const _RotatingAurora();

  @override
  State<_RotatingAurora> createState() => _RotatingAuroraState();
}

class _RotatingAuroraState extends State<_RotatingAurora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Transform.rotate(
          angle: _c.value * 2 * math.pi,
          child: Container(
            width: 920,
            height: 560,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: math.pi / 2,
                endAngle: math.pi / 2 + 2 * math.pi,
                colors: [
                  Colors.transparent,
                  AppColors.brandBlue.withValues(alpha: 0.18),
                  Colors.transparent,
                  AppColors.v3Indigo.withValues(alpha: 0.18),
                  Colors.transparent,
                  AppColors.accentPink.withValues(alpha: 0.16),
                  Colors.transparent,
                ],
                transform: GradientRotation(0),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

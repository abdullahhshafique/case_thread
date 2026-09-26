import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../rooms/rooms_providers.dart';

/// A 52 px ring showing the ratio of verified alibis to total alibis
/// (v3 §7 donut). Taps nothing — purely informational, reads
/// [attentionCountsProvider] so it re-renders when counts change.
class TaskDonut extends ConsumerWidget {
  const TaskDonut({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(attentionCountsProvider(roomId));
    return counts.when(
      loading: () => const SizedBox(
        width: 52, height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final total = data.totalAlibis;
        final verified = data.alibiVerified;
        if (total == 0) return const SizedBox.shrink();
        final pct = verified / total;
        return SizedBox(
          width: 52,
          height: 52,
          child: CustomPaint(
            painter: _DonutPainter(progress: pct),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track (background)
    final trackPaint = Paint()
      ..color = AppColors.consoleBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..color = AppColors.stateSuccess
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress;
}

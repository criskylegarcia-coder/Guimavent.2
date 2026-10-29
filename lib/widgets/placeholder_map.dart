import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// A static, hand-drawn "map" used until a real map widget (Google Maps or
// similar, needs an API key) is wired in. Draws a light gray background
// with a few faint blocks/roads for texture, a dotted route line, and two
// markers — everything is fractional (0..1) so it scales to any box size.
class PlaceholderMap extends StatelessWidget {
  final Offset startFraction;
  final Offset endFraction;
  final Color startColor;
  final Color endColor;
  // When true, the start marker is drawn as a "current position" dot
  // (used on the turn-by-turn screen) instead of a plain marker.
  final bool startIsCurrentPosition;

  const PlaceholderMap({
    super.key,
    this.startFraction = const Offset(0.22, 0.74),
    this.endFraction = const Offset(0.74, 0.22),
    this.startColor = AppColors.primary,
    this.endColor = AppColors.accentOrange,
    this.startIsCurrentPosition = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlaceholderMapPainter(
        start: startFraction,
        end: endFraction,
        startColor: startColor,
        endColor: endColor,
        startIsCurrentPosition: startIsCurrentPosition,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PlaceholderMapPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color startColor;
  final Color endColor;
  final bool startIsCurrentPosition;

  _PlaceholderMapPainter({
    required this.start,
    required this.end,
    required this.startColor,
    required this.endColor,
    required this.startIsCurrentPosition,
  });

  // Fixed, fractional rectangles just to suggest city blocks — not real
  // geodata, purely decorative.
  static const List<Rect> _blocks = [
    Rect.fromLTWH(0.05, 0.08, 0.22, 0.16),
    Rect.fromLTWH(0.62, 0.10, 0.28, 0.14),
    Rect.fromLTWH(0.10, 0.50, 0.18, 0.20),
    Rect.fromLTWH(0.55, 0.55, 0.30, 0.22),
    Rect.fromLTWH(0.35, 0.30, 0.16, 0.12),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface);

    final blockPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (final block in _blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            block.left * size.width,
            block.top * size.height,
            block.width * size.width,
            block.height * size.height,
          ),
          const Radius.circular(6),
        ),
        blockPaint,
      );
    }

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, size.height * 0.42),
      Offset(size.width, size.height * 0.38),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.46, size.height),
      roadPaint,
    );

    final startPoint = Offset(start.dx * size.width, start.dy * size.height);
    final endPoint = Offset(end.dx * size.width, end.dy * size.height);

    _drawDottedLine(canvas, startPoint, endPoint, AppColors.primary);

    if (startIsCurrentPosition) {
      _drawCurrentPositionMarker(canvas, startPoint, startColor);
    } else {
      _drawMarker(canvas, startPoint, startColor);
    }
    _drawMarker(canvas, endPoint, endColor);
  }

  void _drawDottedLine(Canvas canvas, Offset from, Offset to, Color color) {
    const dashLength = 8.0;
    const gapLength = 6.0;
    final totalDistance = (to - from).distance;
    if (totalDistance == 0) return;
    final direction = (to - from) / totalDistance;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    var covered = 0.0;
    while (covered < totalDistance) {
      final segmentEnd = (covered + dashLength).clamp(0.0, totalDistance);
      canvas.drawLine(
        from + direction * covered,
        from + direction * segmentEnd,
        paint,
      );
      covered += dashLength + gapLength;
    }
  }

  void _drawMarker(Canvas canvas, Offset center, Color color) {
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 4), width: 16, height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(center, 8, Paint()..color = color);
  }

  void _drawCurrentPositionMarker(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 16, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    canvas.drawCircle(center, 7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PlaceholderMapPainter oldDelegate) {
    return start != oldDelegate.start ||
        end != oldDelegate.end ||
        startColor != oldDelegate.startColor ||
        endColor != oldDelegate.endColor ||
        startIsCurrentPosition != oldDelegate.startIsCurrentPosition;
  }
}

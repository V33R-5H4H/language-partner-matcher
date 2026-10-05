import 'dart:math' as math;
import 'package:flutter/material.dart';

class Particle {
  double radiusFraction;
  double angle;
  double size;
  double opacity;
  double speed;

  Particle({
    required this.radiusFraction,
    required this.angle,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}

class RadarParticlePainter extends CustomPainter {
  final double animationValue;
  final bool isSearching;
  final List<Particle> particles;

  RadarParticlePainter({
    required this.animationValue,
    required this.isSearching,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.46;

    if (maxRadius <= 10) return;

    // 1. Deep Solid WhatsApp Dark Canvas Background
    final bgPaint = Paint()
      ..color = const Color(0xFF111B21)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Uniformly Distributed Star Particles across Circular Radar Field
    for (final p in particles) {
      final alpha = (p.opacity * (0.35 + 0.65 * math.sin(animationValue * 2 * math.pi * p.speed))).clamp(0.12, 0.75);
      final pPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      final currentAngle = p.angle + (animationValue * 0.08 * p.speed);
      final currentDist = p.radiusFraction * maxRadius;
      final px = center.dx + currentDist * math.cos(currentAngle);
      final py = center.dy + currentDist * math.sin(currentAngle);

      canvas.drawCircle(Offset(px, py), p.size.clamp(1.0, 2.0), pPaint);
    }

    // 3. Crisp Concentric Radar Range Rings (Proportional & Clear)
    final ringFractions = [0.38, 0.62, 0.84, 1.00];
    for (int i = 0; i < ringFractions.length; i++) {
      final r = maxRadius * ringFractions[i];
      final isOuter = i == ringFractions.length - 1;

      final ringPaint = Paint()
        ..color = isOuter ? const Color(0xFF3A4B53) : const Color(0xFF24343B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isOuter ? 1.5 : 1.0;

      canvas.drawCircle(center, r, ringPaint);
    }

    // 4. Subtle Crosshair Lines with Avatar Clearance Gap
    const avatarGap = 44.0;
    final crosshairPaint = Paint()
      ..color = const Color(0xFF26373E)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy - avatarGap),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + avatarGap),
      Offset(center.dx, center.dy + maxRadius),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx - avatarGap, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx + avatarGap, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crosshairPaint,
    );

    // 5. Perimeter Compass Ticks (Every 30 degrees)
    final tickPaint = Paint()
      ..color = const Color(0xFF3A4B53)
      ..strokeWidth = 1.0;
    final majorTickPaint = Paint()
      ..color = const Color(0xFF00A884).withValues(alpha: 0.8)
      ..strokeWidth = 1.5;

    for (int deg = 0; deg < 360; deg += 30) {
      final rad = deg * math.pi / 180.0;
      final isCardinal = deg % 90 == 0;
      final tickLength = isCardinal ? 8.0 : 4.0;
      final p1 = Offset(
        center.dx + maxRadius * math.cos(rad),
        center.dy + maxRadius * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + (maxRadius - tickLength) * math.cos(rad),
        center.dy + (maxRadius - tickLength) * math.sin(rad),
      );
      canvas.drawLine(p1, p2, isCardinal ? majorTickPaint : tickPaint);
    }

    // 6. Active Searching State: Clean Sonar Sweep & Expanding Rings
    if (isSearching) {
      final pulseProgress = animationValue;
      final pulseRadius = maxRadius * pulseProgress;
      final pulseAlpha = ((1.0 - pulseProgress) * 0.35).clamp(0.0, 1.0);
      final pulsePaint = Paint()
        ..color = const Color(0xFF00A884).withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, pulseRadius, pulsePaint);

      // Clean 360° Sweep gradient fan
      final sweepAngle = animationValue * 2 * math.pi;
      final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);

      final sweepPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0.0,
          endAngle: 2 * math.pi,
          colors: const [
            Color(0x0000A884),
            Color(0x0000A884),
            Color(0x1800A884),
            Color(0x5500A884),
          ],
          stops: const [0.0, 0.75, 0.88, 1.0],
          transform: GradientRotation(sweepAngle),
        ).createShader(sweepRect)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, maxRadius, sweepPaint);

      // Clean leading edge beam line
      final beamEnd = Offset(
        center.dx + maxRadius * math.cos(sweepAngle),
        center.dy + maxRadius * math.sin(sweepAngle),
      );
      final beamPaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.75)
        ..strokeWidth = 1.5;
      canvas.drawLine(center, beamEnd, beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarParticlePainter oldDelegate) => true;
}

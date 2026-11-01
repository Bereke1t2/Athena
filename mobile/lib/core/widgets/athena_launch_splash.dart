import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'dot_grid_background.dart';

/// Cold-start opening splash overlay for Athena.
///
/// Wraps the root MaterialApp child and displays a cinematic aperture emblem
/// animation upon initial app open:
/// 1. Rapid initial spin that smoothly decelerates to a halt (Cubic ease-out).
/// 2. Iris aperture expansion ("and then open") with an emerald lens pulse and tactile haptic.
/// 3. Seamless curtain dissolve into the dark Resarc workspace.
///
/// Automatically disposes itself after completion or on tap, leaving zero overhead.
class AthenaLaunchSplash extends StatefulWidget {
  const AthenaLaunchSplash({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2200),
    this.onCompleted,
    this.autoStart = true,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback? onCompleted;
  final bool autoStart;

  @override
  State<AthenaLaunchSplash> createState() => _AthenaLaunchSplashState();
}

class _AthenaLaunchSplashState extends State<AthenaLaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnim;
  late final Animation<double> _openAnim;
  late final Animation<double> _fadeScaleAnim;
  late final Animation<double> _textFadeAnim;

  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 1. Rotation: 3 full revolutions (1080 deg), starts very fast and decelerates dramatically
    _rotationAnim = Tween<double>(begin: 0.0, end: 3.0 * 2 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.68,
          curve: Cubic(0.08, 0.82, 0.15, 1.0),
        ),
      ),
    );

    // 2. Aperture opening: blades expand outward + emerald core glows (1400ms - 1950ms)
    _openAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.62,
          0.88,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // 3. Editorial typography fade-in
    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.20,
          0.60,
          curve: Curves.easeOut,
        ),
      ),
    );

    // 4. Final curtain reveal: scale up and fade out overlay (1850ms - 2200ms)
    _fadeScaleAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.84,
          1.0,
          curve: Curves.easeInOutCubic,
        ),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });

    // Fire tactile haptic feedback when aperture opens
    _controller.addListener(() {
      if (_controller.value >= 0.65 && _controller.value <= 0.67) {
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
      }
    });

    if (widget.autoStart) {
      _controller.forward();
    }
  }

  void _finish() {
    if (_isFinished) return;
    setState(() => _isFinished = true);
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Underlying main application view
        widget.child,

        // Cinematic Launch Splash Overlay
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final opacity = _fadeScaleAnim.value.clamp(0.0, 1.0);
            if (opacity <= 0.001) {
              return const SizedBox.shrink();
            }

            final revealScale = 1.0 + (1.0 - _fadeScaleAnim.value) * 0.18;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: revealScale,
                child: GestureDetector(
                  onTap: _finish,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: AppTheme.deepDark, // Obsidian black (#101216)
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        // Subtle technical dot-grid canvas
                        const Positioned.fill(
                          child: DotGridBackground(
                            dotColor: AppTheme.dotGridDark,
                            backgroundColor: AppTheme.deepDark,
                            spacing: 24,
                            dotRadius: 1.0,
                            child: SizedBox.expand(),
                          ),
                        ),

                        // Center Emblem & Typography
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Rotating & Opening Aperture Logo
                            AthenaAnimatedOpeningLogo(
                              rotation: _rotationAnim.value,
                              openFactor: _openAnim.value,
                              size: 92.0,
                            ),

                            const SizedBox(height: 36),

                            // Editorial Brandmark & Subtitle
                            Opacity(
                              opacity: _textFadeAnim.value,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'ATHENA',
                                        style: TextStyle(
                                          color: Color(0xFFF9FAFB),
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 4.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.coral,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'RESEARCH INTELLIGENCE',
                                        style: TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Subtle bottom skip indicator
                        Positioned(
                          bottom: 40,
                          child: Opacity(
                            opacity: (_textFadeAnim.value * 0.6).clamp(0.0, 1.0),
                            child: const Text(
                              'Tap anywhere to start',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Standalone Animated Logo Widget rendering the spinning and iris-opening aperture.
class AthenaAnimatedOpeningLogo extends StatelessWidget {
  const AthenaAnimatedOpeningLogo({
    super.key,
    required this.rotation,
    required this.openFactor,
    this.size = 88.0,
    this.coralColor = AppTheme.coral,
    this.dotColor = const Color(0xFF10B981),
  });

  final double rotation;
  final double openFactor;
  final double size;
  final Color coralColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Outer Radial Aura Glow
          Container(
            width: size * 1.4,
            height: size * 1.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: coralColor.withValues(alpha: 0.18 + openFactor * 0.15),
                  blurRadius: 44,
                  spreadRadius: 8 + openFactor * 12,
                ),
                BoxShadow(
                  color: dotColor.withValues(alpha: openFactor * 0.22),
                  blurRadius: 28,
                  spreadRadius: openFactor * 6,
                ),
              ],
            ),
          ),

          // Technical Outline Halo with cardinal tick marks
          CustomPaint(
            size: Size(size * 1.35, size * 1.35),
            painter: _TechnicalRingPainter(
              color: const Color(0xFF282C38),
              tickColor: AppTheme.coral.withValues(alpha: 0.6),
              openFactor: openFactor,
            ),
          ),

          // Central Rotating & Iris-Opening Emblem
          Transform.rotate(
            angle: rotation,
            child: CustomPaint(
              size: Size(size, size),
              painter: AthenaApertureLogoPainter(
                coralColor: coralColor,
                dotColor: dotColor,
                openFactor: openFactor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the 4-quarter Athena aperture emblem with dynamic iris separation.
class AthenaApertureLogoPainter extends CustomPainter {
  const AthenaApertureLogoPainter({
    required this.coralColor,
    required this.dotColor,
    required this.openFactor,
  });

  final Color coralColor;
  final Color dotColor;
  final double openFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // The 4 quarter segments separate outward by 'gap' as openFactor increases from 0 -> 1
    final gap = 1.5 + openFactor * 6.5;

    final bladePaint = Paint()
      ..color = coralColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draw the 4 quarter blades with dynamic aperture separation
    _drawBlade(canvas, center, radius, gap, -1, -1, bladePaint); // Top-Left
    _drawBlade(canvas, center, radius, gap, 1, -1, bladePaint);  // Top-Right
    _drawBlade(canvas, center, radius, gap, 1, 1, bladePaint);   // Bottom-Right
    _drawBlade(canvas, center, radius, gap, -1, 1, bladePaint);  // Bottom-Left

    // Center precision aperture ring cutout (matches dark background)
    final cutoutRadius = radius * (0.32 + openFactor * 0.08);
    final cutoutPaint = Paint()
      ..color = AppTheme.deepDark
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, cutoutRadius, cutoutPaint);

    // Subtle crisp border ring around the center aperture
    final cutoutBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true;
    canvas.drawCircle(center, cutoutRadius, cutoutBorderPaint);

    // Glowing Emerald Center Dot with dynamic pulse
    final dotRadius = radius * (0.16 + openFactor * 0.06);
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, dotRadius, dotPaint);

    // Inner bright specular reflection dot
    final specPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(
      Offset(center.dx - dotRadius * 0.35, center.dy - dotRadius * 0.35),
      dotRadius * 0.35,
      specPaint,
    );
  }

  void _drawBlade(
    Canvas canvas,
    Offset center,
    double radius,
    double gap,
    double dirX,
    double dirY,
    Paint paint,
  ) {
    final offset = Offset(dirX * gap, dirY * gap);
    final bladeCenter = center + offset;

    final startAngle = dirX > 0
        ? (dirY > 0 ? 0.0 : 3 * math.pi / 2)
        : (dirY > 0 ? math.pi / 2 : math.pi);

    final path = Path()
      ..moveTo(bladeCenter.dx, bladeCenter.dy)
      ..arcTo(
        Rect.fromCircle(center: bladeCenter, radius: radius),
        startAngle,
        math.pi / 2,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AthenaApertureLogoPainter oldDelegate) {
    return oldDelegate.openFactor != openFactor ||
        oldDelegate.coralColor != coralColor ||
        oldDelegate.dotColor != dotColor;
  }
}

/// Technical circular ring with precision cardinal tick marks.
class _TechnicalRingPainter extends CustomPainter {
  const _TechnicalRingPainter({
    required this.color,
    required this.tickColor,
    required this.openFactor,
  });

  final Color color;
  final Color tickColor;
  final double openFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Circular guideline
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, ringPaint);

    // 4 cardinal tick lines
    final tickPaint = Paint()
      ..color = tickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    const tickLength = 5.0;
    // Top
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - tickLength),
      Offset(center.dx, center.dy - radius + tickLength),
      tickPaint,
    );
    // Bottom
    canvas.drawLine(
      Offset(center.dx, center.dy + radius - tickLength),
      Offset(center.dx, center.dy + radius + tickLength),
      tickPaint,
    );
    // Left
    canvas.drawLine(
      Offset(center.dx - radius - tickLength, center.dy),
      Offset(center.dx - radius + tickLength, center.dy),
      tickPaint,
    );
    // Right
    canvas.drawLine(
      Offset(center.dx + radius - tickLength, center.dy),
      Offset(center.dx + radius + tickLength, center.dy),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TechnicalRingPainter oldDelegate) {
    return oldDelegate.openFactor != openFactor ||
        oldDelegate.color != color ||
        oldDelegate.tickColor != tickColor;
  }
}

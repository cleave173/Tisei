import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'character_scenario.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

void showCharacterOverlay(
  BuildContext context, {
  required CharacterScenario scenario,
  String? imagePath,
  Duration autoDismissDuration = const Duration(seconds: 5),
}) {
  final OverlayState? overlayState = Overlay.maybeOf(context);
  if (overlayState == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CharacterOverlay(
      scenario: scenario,
      imagePath: imagePath,
      autoDismissDuration: autoDismissDuration,
      onDismiss: entry.remove,
    ),
  );
  overlayState.insert(entry);
}

// ---------------------------------------------------------------------------
// Scenario theme
// ---------------------------------------------------------------------------

class _ScenarioTheme {
  const _ScenarioTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.hasConfetti,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final bool hasConfetti;

  static _ScenarioTheme of(CharacterScenario s) => switch (s) {
    CharacterScenario.lessonCompleted => const _ScenarioTheme(
      primary: Color(0xFFB8872E),
      secondary: Color(0xFF27546B),
      accent: Color(0xFFEAC66B),
      hasConfetti: true,
    ),
    CharacterScenario.testPassed => const _ScenarioTheme(
      primary: Color(0xFF2F6F73),
      secondary: Color(0xFF273D63),
      accent: Color(0xFFE8C766),
      hasConfetti: true,
    ),
    CharacterScenario.testFailed => const _ScenarioTheme(
      primary: Color(0xFFC84C5A),
      secondary: Color(0xFF50406F),
      accent: Color(0xFFE8C766),
      hasConfetti: false,
    ),
  };
}

// ---------------------------------------------------------------------------
// Confetti — time-based, painter repaints via repaint: animation
// ---------------------------------------------------------------------------

const int _kParticleCount = 72;
const double _kCycleSecs = 8.0;

const List<Color> _kConfettiColors = <Color>[
  Color(0xFFC84C5A),
  Color(0xFFE8C766),
  Color(0xFF2F6F73),
  Color(0xFF5C83A8),
  Color(0xFF50406F),
  Color(0xFFFFFFFF),
  Color(0xFFB8872E),
  Color(0xFF8E6A42),
];

class _ParticleData {
  const _ParticleData({
    required this.x,
    required this.y0,
    required this.speed,
    required this.angle0,
    required this.spin,
    required this.w,
    required this.h,
    required this.color,
  });

  final double x;
  final double y0;
  final double speed;
  final double angle0;
  final double spin;
  final double w;
  final double h;
  final Color color;

  double yAt(double t, double screenH) =>
      (y0 + speed * t) % (screenH + 40) - 20;
  double angleAt(double t) => angle0 + spin * t;
}

List<_ParticleData> _buildParticles(Size size) {
  final Random rng = Random(12345);
  return List<_ParticleData>.generate(_kParticleCount, (_) {
    return _ParticleData(
      x: rng.nextDouble() * size.width,
      y0: -rng.nextDouble() * size.height,
      speed: 120 + rng.nextDouble() * 200,
      angle0: rng.nextDouble() * 3.14159 * 2,
      spin: (rng.nextDouble() - 0.5) * 6,
      w: 6 + rng.nextDouble() * 10,
      h: 3 + rng.nextDouble() * 5,
      color: _kConfettiColors[rng.nextInt(_kConfettiColors.length)],
    );
  });
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.animation})
    : super(repaint: animation);

  final List<_ParticleData> particles;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = animation.value * _kCycleSecs;
    final Paint paint = Paint();
    for (final _ParticleData p in particles) {
      final double y = p.yAt(t, size.height);
      final double angle = p.angleAt(t);
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

// ---------------------------------------------------------------------------
// Overlay root widget
// ---------------------------------------------------------------------------

class _CharacterOverlay extends StatefulWidget {
  const _CharacterOverlay({
    required this.scenario,
    required this.autoDismissDuration,
    required this.onDismiss,
    this.imagePath,
  });

  final CharacterScenario scenario;
  final String? imagePath;
  final Duration autoDismissDuration;
  final VoidCallback onDismiss;

  @override
  State<_CharacterOverlay> createState() => _CharacterOverlayState();
}

class _CharacterOverlayState extends State<_CharacterOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _confettiCtrl;
  late final AnimationController _bounceCtrl;

  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _bounceAnim;

  List<_ParticleData> _particles = <_ParticleData>[];
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.34), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _enterCtrl,
            curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    _fadeAnim = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.08, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);
    _bounceAnim = CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut);

    _enterCtrl.forward();
    Future.delayed(widget.autoDismissDuration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    setState(() => _dismissing = true);
    await _enterCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
    widget.onDismiss();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _confettiCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ScenarioTheme theme = _ScenarioTheme.of(widget.scenario);

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_particles.isEmpty && theme.hasConfetti) {
          _particles = _buildParticles(size);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: Stack(
            children: <Widget>[
              // Backdrop
              FadeTransition(
                opacity: _fadeAnim,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF111318).withValues(alpha: 0.76),
                        theme.secondary.withValues(alpha: 0.52),
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),

              // Confetti
              if (theme.hasConfetti && _particles.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ConfettiPainter(
                        particles: _particles,
                        animation: _confettiCtrl,
                      ),
                    ),
                  ),
                ),

              // Sparkle row above panel
              if (theme.hasConfetti)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 286,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _SparkleRow(color: theme.accent),
                  ),
                ),

              // Main panel
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _CharacterPanel(
                    scenario: widget.scenario,
                    imagePath: widget.imagePath,
                    theme: theme,
                    bounceAnim: _bounceAnim,
                    scaleAnim: _scaleAnim,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sparkle row
// ---------------------------------------------------------------------------

class _SparkleRow extends StatelessWidget {
  const _SparkleRow({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List<Widget>.generate(6, (int i) {
        return Text(
          i.isEven ? '\u2736' : '\u2737',
          style: TextStyle(
            fontSize: 12 + (i % 3) * 5.0,
            color: color.withValues(alpha: 0.55 + (i % 2) * 0.35),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------

class _CharacterPanel extends StatelessWidget {
  const _CharacterPanel({
    required this.scenario,
    required this.theme,
    required this.bounceAnim,
    required this.scaleAnim,
    this.imagePath,
  });

  final CharacterScenario scenario;
  final _ScenarioTheme theme;
  final Animation<double> bounceAnim;
  final Animation<double> scaleAnim;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark
        ? Color.lerp(
            Theme.of(context).colorScheme.surface,
            theme.primary,
            0.07,
          )!
        : Theme.of(context).colorScheme.surface;

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool compact = screenWidth < 390;

    return SizedBox(
      height: compact ? 350 : 364,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: compact ? 72 : 82,
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.accent.withValues(alpha: 0.36),
                    width: 1.2,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.secondary.withValues(alpha: 0.34),
                    blurRadius: 44,
                    spreadRadius: -6,
                    offset: const Offset(0, -12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(24, 28, compact ? 116 : 132, 28),
              child: _MessageContent(
                scenario: scenario,
                theme: theme,
                compact: compact,
              ),
            ),
          ),

          // Dismiss hint
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'character.tap_dismiss'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.28),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

          // Character
          Positioned(
            right: compact ? 4 : 12,
            bottom: 18,
            child: _BouncingCharacter(
              scenario: scenario,
              imagePath: imagePath,
              theme: theme,
              bounceAnim: bounceAnim,
              scaleAnim: scaleAnim,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message content
// ---------------------------------------------------------------------------

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.scenario,
    required this.theme,
    required this.compact,
  });

  final CharacterScenario scenario;
  final _ScenarioTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            scenario.nameKey.tr(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.primary,
              letterSpacing: 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          scenario.messageKey.tr(),
          style: TextStyle(
            fontSize: compact ? 21 : 23,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: 0,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          scenario.subMessageKey.tr(),
          style: TextStyle(
            fontSize: compact ? 12 : 12.5,
            height: 1.38,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bouncing character
// ---------------------------------------------------------------------------

class _BouncingCharacter extends StatelessWidget {
  const _BouncingCharacter({
    required this.scenario,
    required this.theme,
    required this.bounceAnim,
    required this.scaleAnim,
    this.imagePath,
  });

  final CharacterScenario scenario;
  final _ScenarioTheme theme;
  final Animation<double> bounceAnim;
  final Animation<double> scaleAnim;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[bounceAnim, scaleAnim]),
      builder: (BuildContext ctx, Widget? child) {
        final double floatOffset = (bounceAnim.value - 0.5) * 10.0;
        final double tilt = sin(bounceAnim.value * pi * 2) * 0.025;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: scaleAnim.value,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: imagePath != null
          ? _CustomImageChar(
              imagePath: imagePath!,
              scenario: scenario,
              theme: theme,
            )
          : _DefaultMascot(scenario: scenario, theme: theme),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom image character
// ---------------------------------------------------------------------------

class _CustomImageChar extends StatelessWidget {
  const _CustomImageChar({
    required this.imagePath,
    required this.scenario,
    required this.theme,
  });

  final String imagePath;
  final CharacterScenario scenario;
  final _ScenarioTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 232,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned.fill(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  _DefaultMascot(scenario: scenario, theme: theme),
            ),
          ),
          const Positioned(top: 2, child: _Taqiya(width: 66, height: 39)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Default mascot  (CustomPainter)
// ---------------------------------------------------------------------------

class _DefaultMascot extends StatelessWidget {
  const _DefaultMascot({required this.scenario, required this.theme});

  final CharacterScenario scenario;
  final _ScenarioTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 202,
      child: CustomPaint(
        painter: _MascotPainter(
          primary: theme.primary,
          secondary: theme.secondary,
          scenario: scenario,
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  const _MascotPainter({
    required this.primary,
    required this.secondary,
    required this.scenario,
  });

  final Color primary;
  final Color secondary;
  final CharacterScenario scenario;

  static const double _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.58;
    final double r = size.width * 0.37;

    _drawGlow(canvas, cx, cy, r);
    _drawBody(canvas, cx, cy, r, size);
    _drawEyes(canvas, cx, cy, r);
    _drawMouth(canvas, cx, cy, r);
    _drawDecorations(canvas, cx, cy, r);
    _drawHat(canvas, cx, cy, r);
  }

  void _drawGlow(Canvas canvas, double cx, double cy, double r) {
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.5,
      Paint()
        ..color = primary.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  void _drawBody(Canvas canvas, double cx, double cy, double r, Size size) {
    // Drop shadow
    canvas.drawCircle(
      Offset(cx, cy + r * 0.65),
      r * 0.52,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Gradient body
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: r * 1.86,
        height: r * 2.08,
      ),
      Radius.circular(r * 0.58),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: <Color>[
            Color.lerp(primary, Colors.white, 0.45)!,
            primary,
            secondary,
          ],
          stops: const <double>[0.0, 0.42, 1.0],
        ).createShader(body.outerRect),
    );

    // Specular top-left highlight
    canvas.drawCircle(
      Offset(cx - r * 0.30, cy - r * 0.33),
      r * 0.27,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final Paint sashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - r * 0.56, cy + r * 0.45),
      Offset(cx + r * 0.56, cy + r * 0.14),
      sashPaint,
    );
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r) {
    final double eyeY = cy - r * 0.17;
    final double eyeOffX = r * 0.34;
    final double eyeR = r * 0.215;
    final double pupilR = eyeR * 0.63;
    final double shineR = pupilR * 0.38;

    for (final double sign in <double>[-1.0, 1.0]) {
      final Offset center = Offset(cx + sign * eyeOffX, eyeY);

      canvas.drawCircle(center, eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(center.dx - sign * pupilR * 0.15, center.dy + pupilR * 0.08),
        pupilR,
        Paint()..color = const Color(0xFF263238),
      );
      canvas.drawCircle(
        Offset(center.dx + sign * pupilR * 0.30, center.dy - pupilR * 0.32),
        shineR,
        Paint()..color = Colors.white,
      );
    }

    // Eyebrows
    final Paint browPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.075
      ..strokeCap = StrokeCap.round;

    for (final double sign in <double>[-1.0, 1.0]) {
      final double bx = cx + sign * eyeOffX;
      final double by = cy - r * 0.17 - r * 0.215 * 1.35;
      final double dip = scenario == CharacterScenario.testFailed
          ? sign * r * 0.13
          : -r * 0.04;
      final Path brow = Path()
        ..moveTo(bx - sign * r * 0.18, by + dip.abs() * 0.5)
        ..quadraticBezierTo(
          bx,
          by + dip,
          bx + sign * r * 0.18,
          by + dip.abs() * 0.5,
        );
      canvas.drawPath(brow, browPaint);
    }
  }

  void _drawMouth(Canvas canvas, double cx, double cy, double r) {
    final Paint mouth = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;

    final double mouthY = cy + r * 0.38;
    final double mw = r * 0.44;
    final Path path = Path();

    if (scenario != CharacterScenario.testFailed) {
      path.moveTo(cx - mw, mouthY);
      path.quadraticBezierTo(cx, mouthY + r * 0.27, cx + mw, mouthY);

      // Cheeks
      final Paint cheek = Paint()..color = Colors.white.withValues(alpha: 0.17);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - r * 0.53, mouthY - r * 0.05),
          width: r * 0.38,
          height: r * 0.22,
        ),
        cheek,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + r * 0.53, mouthY - r * 0.05),
          width: r * 0.38,
          height: r * 0.22,
        ),
        cheek,
      );
    } else {
      path.moveTo(cx - mw, mouthY + r * 0.13);
      path.quadraticBezierTo(cx, mouthY - r * 0.15, cx + mw, mouthY + r * 0.13);
    }
    canvas.drawPath(path, mouth);
  }

  void _drawDecorations(Canvas canvas, double cx, double cy, double r) {
    if (scenario == CharacterScenario.testFailed) {
      _drawSweatDrop(canvas, cx + r * 0.64, cy - r * 0.08, r * 0.135);
    } else {
      _drawSparkle(canvas, cx + r * 1.20, cy - r * 0.76, r * 0.155);
      _drawSparkle(canvas, cx - r * 1.15, cy - r * 0.55, r * 0.115);
      _drawSparkle(canvas, cx + r * 0.95, cy + r * 0.68, r * 0.095);
    }
  }

  void _drawHat(Canvas canvas, double cx, double cy, double r) {
    _paintTaqiya(
      canvas,
      Rect.fromCenter(
        center: Offset(cx, cy - r * 1.05),
        width: r * 1.55,
        height: r * 0.8,
      ),
    );
  }

  void _drawSparkle(Canvas canvas, double x, double y, double size) {
    final Path path = Path();
    for (int i = 0; i < 4; i++) {
      final double a = (_pi / 4) * i * 2;
      final double ai = a + _pi / 4;
      if (i == 0) {
        path.moveTo(x + cos(a) * size, y + sin(a) * size);
      } else {
        path.lineTo(x + cos(a) * size, y + sin(a) * size);
      }
      path.lineTo(x + cos(ai) * (size * 0.35), y + sin(ai) * (size * 0.35));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  void _drawSweatDrop(Canvas canvas, double x, double y, double size) {
    final Path path = Path()
      ..moveTo(x, y - size * 2)
      ..quadraticBezierTo(x + size * 1.1, y, x, y + size * 0.6)
      ..quadraticBezierTo(x - size * 1.1, y, x, y - size * 2);
    canvas.drawPath(
      path,
      Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.82),
    );
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.primary != primary ||
      old.secondary != secondary ||
      old.scenario != scenario;
}

class _Taqiya extends StatelessWidget {
  const _Taqiya({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: const _TaqiyaPainter()),
    );
  }
}

class _TaqiyaPainter extends CustomPainter {
  const _TaqiyaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintTaqiya(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(_TaqiyaPainter oldDelegate) => false;
}

void _paintTaqiya(Canvas canvas, Rect rect) {
  final double w = rect.width;
  final double h = rect.height;
  final double left = rect.left;
  final double top = rect.top;
  final double cx = rect.center.dx;

  final Rect brimRect = Rect.fromLTWH(
    left + w * 0.05,
    top + h * 0.48,
    w * 0.9,
    h * 0.31,
  );
  final Rect domeRect = Rect.fromLTWH(
    left + w * 0.12,
    top + h * 0.06,
    w * 0.76,
    h * 0.68,
  );

  final Path dome = Path()
    ..moveTo(domeRect.left, domeRect.bottom)
    ..quadraticBezierTo(
      cx,
      domeRect.top - h * 0.05,
      domeRect.right,
      domeRect.bottom,
    )
    ..close();

  canvas.drawShadow(dome, Colors.black.withValues(alpha: 0.30), 5, true);
  canvas.drawPath(
    dome,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF234C51), Color(0xFF142F35)],
      ).createShader(domeRect),
  );
  canvas.drawOval(
    brimRect,
    Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFE7C568), Color(0xFFB8872E)],
      ).createShader(brimRect),
  );

  final Paint stitch = Paint()
    ..color = const Color(0xFFFFE8A6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.1, w * 0.025)
    ..strokeCap = StrokeCap.round;

  final double patternY = top + h * 0.56;
  for (int i = 0; i < 4; i++) {
    final double px = left + w * (0.25 + i * 0.16);
    final Path motif = Path()
      ..moveTo(px - w * 0.045, patternY)
      ..quadraticBezierTo(px, patternY - h * 0.12, px + w * 0.045, patternY)
      ..quadraticBezierTo(px, patternY + h * 0.10, px - w * 0.045, patternY);
    canvas.drawPath(motif, stitch);
  }

  final Paint topLine = Paint()
    ..color = const Color(0xFFFFE8A6).withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, w * 0.018)
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(
    Rect.fromLTWH(left + w * 0.28, top + h * 0.22, w * 0.44, h * 0.28),
    pi,
    pi,
    false,
    topLine,
  );
}

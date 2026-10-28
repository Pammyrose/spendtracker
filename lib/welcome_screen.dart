import 'package:flutter/material.dart';

import 'app_theme.dart';

// Brand artwork stays pink regardless of the dashboard theme.
const _brandPalette = AppPalette(
  name: 'Brand',
  accent: Color(0xFFFF5C83),
  background: Color(0xFFFFF8F3),
  surface: Color(0xFFFFDFE6),
  soft: Color(0xFFFFE4E9),
  border: Color(0xFFE9577B),
  heroStart: Color(0xFFFFCAD8),
  heroEnd: Color(0xFFFF80A1),
  ink: Color(0xFF192134),
);

// The welcome page opens its destination without leaving an extra back-stack entry.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.destination});
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    const palette = _brandPalette;
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: palette.accent,
          primary: palette.accent,
        ),
      ),
      child: Scaffold(
        body: CustomPaint(
          key: const Key('welcome-background'),
          painter: _WelcomeBackground(palette),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          // Keep the logo accessible on short landscape screens.
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  image: true,
                                  label: 'Wallet with a gold coin',
                                  child: SizedBox(
                                    width: 128,
                                    height: 128,
                                    child: CustomPaint(
                                      key: const Key('welcome-wallet'),
                                      painter: _WalletPainter(palette),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Spend',
                                          style: TextStyle(color: palette.ink),
                                        ),
                                        TextSpan(
                                          text: 'Tracker',
                                          style: TextStyle(
                                            color: palette.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Track today.\nPlan for tomorrow.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF697B90),
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 36, top: 12),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF698C), Color(0xFFEF5C80)],
                            ),
                            boxShadow: palette.name == 'White'
                                ? const []
                                : [
                                    BoxShadow(
                                      color: palette.accent.withValues(
                                        alpha: .16,
                                      ),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => Navigator.of(context)
                                .pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => destination,
                                  ),
                                ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Paint decorative shapes directly, so the background adapts to any screen size.
// Reuse the original pink artwork on authentication screens, with a light
// backing so the logo remains readable when the app uses a dark theme.
class SpendTrackerLogo extends StatelessWidget {
  const SpendTrackerLogo({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: _brandPalette.background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(painter: _WalletPainter(_brandPalette)),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Spend',
                style: TextStyle(color: _brandPalette.ink),
              ),
              TextSpan(
                text: 'Tracker',
                style: TextStyle(color: _brandPalette.accent),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ],
    ),
  );
}

class _WelcomeBackground extends CustomPainter {
  const _WelcomeBackground(this.palette);
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8F3), Color(0xFFFFF6F7)],
        ).createShader(bounds),
    );
    if (palette.name == 'White') return;
    canvas.save();
    canvas.clipRect(bounds);
    final pink = Paint()..color = palette.soft.withValues(alpha: 0.68);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .74,
        -size.height * .01,
        size.width * .65,
        size.height * .30,
      ),
      pink,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * .52,
        size.height * .68,
        size.width * 1.04,
        size.height * .45,
      ),
      pink,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .88,
        size.height * .57,
        size.width * .39,
        size.height * .30,
      ),
      pink,
    );
    canvas.drawCircle(
      Offset(size.width * .73, size.height * .74),
      size.width * .058,
      pink,
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .80),
      size.width * .022,
      pink,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .52,
        size.height * .90,
        size.width * .55,
        size.height * .25,
      ),
      pink,
    );
    canvas.save();
    canvas.translate(-size.width * .08, size.height * .18);
    canvas.rotate(-.70);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * .48, size.width * .16),
        const Radius.circular(40),
      ),
      pink,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-size.width * .15, size.height * .36);
    canvas.rotate(-.88);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * .40, size.width * .15),
        const Radius.circular(40),
      ),
      pink,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WelcomeBackground oldDelegate) =>
      oldDelegate.palette != palette;
}

// A vector wallet keeps the illustration sharp without downloading image assets.
class _WalletPainter extends CustomPainter {
  const _WalletPainter(this.palette);
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    final coinRect = Rect.fromCircle(center: const Offset(69, 36), radius: 21);
    canvas.drawCircle(
      const Offset(69, 36),
      21,
      Paint()
        ..shader = LinearGradient(
          colors: [Color(0xFFFFD782), Color(0xFFFFAB43)],
        ).createShader(coinRect),
    );
    canvas.drawCircle(
      const Offset(69, 36),
      15,
      Paint()..color = const Color(0xFFFFE2A0),
    );
    final coinMark = Paint()
      ..color = const Color(0xFFFFBC60)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(72, 25), const Offset(65, 46), coinMark);
    final seam = Paint()
      ..color = palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final back = Path()
      ..moveTo(28, 55)
      ..lineTo(91, 43)
      ..quadraticBezierTo(102, 40, 102, 52)
      ..lineTo(102, 72)
      ..lineTo(28, 76)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFFFFABC0));
    canvas.drawPath(back, seam);
    final wallet = RRect.fromRectAndRadius(
      const Rect.fromLTWH(26, 55, 80, 60),
      const Radius.circular(9),
    );
    canvas.drawShadow(
      Path()..addRRect(wallet),
      palette.accent.withValues(alpha: .18),
      5,
      false,
    );
    canvas.drawRRect(
      wallet,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.heroEnd],
        ).createShader(wallet.outerRect),
    );
    canvas.drawRRect(wallet, seam);
    canvas.drawLine(
      const Offset(33, 62),
      const Offset(98, 62),
      Paint()
        ..color = palette.surface
        ..strokeWidth = 2,
    );
    final clasp = RRect.fromRectAndRadius(
      const Rect.fromLTWH(80, 77, 28, 22),
      const Radius.circular(9),
    );
    canvas.drawRRect(clasp, Paint()..color = const Color(0xFFF06488));
    canvas.drawCircle(
      const Offset(91, 88),
      4,
      Paint()..color = const Color(0xFFFFE2EB),
    );
    final spark = Paint()
      ..color = const Color(0xFFD47553)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(100, 18), const Offset(104, 11), spark);
    canvas.drawLine(const Offset(107, 28), const Offset(115, 26), spark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WalletPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

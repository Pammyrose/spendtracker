import 'package:flutter/material.dart';

// The welcome page opens the dashboard without leaving an extra back-stack entry.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.destination});
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: const _WelcomeBackground(),
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
                                label: 'Pink wallet with a gold coin',
                                child: SizedBox(
                                  width: 128,
                                  height: 128,
                                  child: CustomPaint(painter: _WalletPainter()),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Spend',
                                        style: TextStyle(
                                          color: Color(0xFF192134),
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Tracker',
                                        style: TextStyle(
                                          color: Color(0xFFFF5C83),
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF698C), Color(0xFFEF5C80)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x20FF5C83),
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
    );
  }
}

// Paint decorative shapes directly, so the background adapts to any screen size.
class _WelcomeBackground extends CustomPainter {
  const _WelcomeBackground();

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
    canvas.save();
    canvas.clipRect(bounds);
    final pink = Paint()
      ..color = const Color(0xFFFFE4E9).withValues(alpha: 0.68);
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
  bool shouldRepaint(covariant _WelcomeBackground oldDelegate) => false;
}

// A vector wallet keeps the illustration sharp without downloading image assets.
class _WalletPainter extends CustomPainter {
  const _WalletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    final coinRect = Rect.fromCircle(center: const Offset(69, 36), radius: 21);
    canvas.drawCircle(
      const Offset(69, 36),
      21,
      Paint()
        ..shader = const LinearGradient(
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
      ..color = const Color(0xFFE9577B)
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
      const Color(0x40D84B70),
      5,
      false,
    );
    canvas.drawRRect(
      wallet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCAD8), Color(0xFFFF80A1)],
        ).createShader(wallet.outerRect),
    );
    canvas.drawRRect(wallet, seam);
    canvas.drawLine(
      const Offset(33, 62),
      const Offset(98, 62),
      Paint()
        ..color = const Color(0xFFFFDFE6)
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
  bool shouldRepaint(covariant _WalletPainter oldDelegate) => false;
}

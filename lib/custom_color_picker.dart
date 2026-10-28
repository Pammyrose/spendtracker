import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

class CustomThemeChoice {
  const CustomThemeChoice(this.color, this.dark);
  final Color color;
  final bool dark;
}

class CustomColorDialog extends StatefulWidget {
  const CustomColorDialog({
    super.key,
    required this.initialColor,
    required this.initialDark,
  });
  final Color initialColor;
  final bool initialDark;
  @override
  State<CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<CustomColorDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initialColor);
  late bool _dark = widget.initialDark;
  late final _hex = TextEditingController(text: _hexCode(widget.initialColor));
  bool _valid = true;
  String _hexCode(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _setColor(HSVColor color) {
    setState(() {
      _hsv = color;
      _hex.text = _hexCode(color.toColor());
      _valid = true;
    });
  }

  void _pick(Offset point, double diameter) {
    final delta = point - Offset(diameter / 2, diameter / 2);
    final hue = (math.atan2(delta.dy, delta.dx) * 180 / math.pi + 360) % 360;
    _setColor(
      HSVColor.fromAHSV(
        1,
        hue,
        (delta.distance / (diameter / 2)).clamp(0, 1),
        _hsv.value,
      ),
    );
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = AppPalette.custom(_hsv.toColor(), dark: _dark);
    return AlertDialog(
      title: const Text('Custom color'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose a color for your app. The welcome screen stays pink.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final diameter = math.min(constraints.maxWidth, 230.0);
                  return Center(
                    child: Semantics(
                      label: 'Color wheel',
                      value:
                          'Hue ${_hsv.hue.round()} degrees, saturation ${(_hsv.saturation * 100).round()} percent',
                      increasedValue:
                          'Hue ${((_hsv.hue + 5) % 360).round()} degrees, saturation ${(_hsv.saturation * 100).round()} percent',
                      decreasedValue:
                          'Hue ${((_hsv.hue + 355) % 360).round()} degrees, saturation ${(_hsv.saturation * 100).round()} percent',
                      onIncrease: () =>
                          _setColor(_hsv.withHue((_hsv.hue + 5) % 360)),
                      onDecrease: () =>
                          _setColor(_hsv.withHue((_hsv.hue + 355) % 360)),
                      child: GestureDetector(
                        key: const Key('custom-color-wheel'),
                        onPanDown: (details) =>
                            _pick(details.localPosition, diameter),
                        onPanUpdate: (details) =>
                            _pick(details.localPosition, diameter),
                        child: SizedBox.square(
                          dimension: diameter,
                          child: CustomPaint(painter: _ColorWheelPainter(_hsv)),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Brightness',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Slider(
                key: const Key('custom-brightness'),
                value: _hsv.value,
                label: '${(_hsv.value * 100).round()}%',
                onChanged: (value) => _setColor(_hsv.withValue(value)),
              ),
              TextField(
                key: const Key('custom-hex'),
                controller: _hex,
                decoration: InputDecoration(
                  labelText: 'Hex color',
                  hintText: '#5C66D6',
                  errorText: _valid ? null : 'Enter six hex digits',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (value) {
                  final text = value.replaceFirst('#', '');
                  final valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text);
                  setState(() {
                    _valid = valid;
                    if (valid) {
                      _hsv = HSVColor.fromColor(
                        Color(0xFF000000 | int.parse(text, radix: 16)),
                      );
                    }
                  });
                },
              ),
              SwitchListTile(
                key: const Key('custom-dark'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Dark appearance',
                  style: TextStyle(fontSize: 13),
                ),
                value: _dark,
                onChanged: (value) => setState(() => _dark = value),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: preview.background,
                  border: Border.all(color: preview.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: preview.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [preview.heroStart, preview.heroEnd],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Your dashboard',
                        style: TextStyle(color: preview.ink, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: preview.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Button color',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: preview.onAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  CustomThemeChoice(_hsv.toColor(), _dark),
                )
              : null,
          child: const Text('Apply color'),
        ),
      ],
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter(this.color);
  final HSVColor color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide / 2;
    final rect = Offset.zero & size;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: [
            for (var hue = 0; hue <= 360; hue += 60)
              HSVColor.fromAHSV(1, hue.toDouble(), 1, color.value).toColor(),
          ],
        ).createShader(rect),
    );
    final neutral = HSVColor.fromAHSV(1, 0, 0, color.value).toColor();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [neutral, neutral.withValues(alpha: 0)],
        ).createShader(rect),
    );
    final angle = color.hue * math.pi / 180;
    final point =
        center +
        Offset(math.cos(angle), math.sin(angle)) * (radius * color.saturation);
    canvas.drawCircle(
      point,
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      point,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) =>
      oldDelegate.color != color;
}

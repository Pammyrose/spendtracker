import 'package:flutter/material.dart';

// Each theme controls the whole page, not just the selected button color.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.name,
    required this.accent,
    required this.background,
    required this.surface,
    required this.soft,
    required this.border,
    required this.heroStart,
    required this.heroEnd,
    this.ink = const Color(0xFF192433),
    this.muted = const Color(0xFF647085),
    this.onAccent = Colors.white,
  });
  final String name;
  final Color accent,
      background,
      surface,
      soft,
      border,
      heroStart,
      heroEnd,
      ink,
      muted,
      onAccent;
  Brightness get brightness =>
      background.computeLuminance() < .18 ? Brightness.dark : Brightness.light;

  factory AppPalette.custom(Color color, {bool dark = false}) {
    final background = Color.lerp(
      dark ? const Color(0xFF101214) : Colors.white,
      color,
      .06,
    )!;
    final surface = Color.lerp(
      dark ? const Color(0xFF1A1D23) : Colors.white,
      color,
      dark ? .08 : .025,
    )!;
    var accent = color;
    double contrast(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return ((first > second ? first : second) + .05) /
          ((first < second ? first : second) + .05);
    }

    // Keep the chosen hue visible against cards, even for white or black picks.
    for (var step = 1; contrast(accent, surface) < 3 && step <= 20; step++) {
      accent = Color.lerp(
        color,
        dark ? Colors.white : Colors.black,
        step / 20,
      )!;
    }
    final onAccent =
        contrast(accent, Colors.white) >= contrast(accent, Colors.black)
        ? Colors.white
        : Colors.black;
    return AppPalette(
      name: 'Custom',
      accent: accent,
      onAccent: onAccent,
      background: background,
      surface: surface,
      soft: Color.lerp(
        dark ? const Color(0xFF2A2E36) : Colors.white,
        color,
        dark ? .20 : .15,
      )!,
      border: Color.lerp(
        dark ? const Color(0xFF3A404C) : Colors.white,
        color,
        .30,
      )!,
      heroStart: Color.lerp(
        dark ? const Color(0xFF252A34) : Colors.white,
        color,
        .30,
      )!,
      heroEnd: Color.lerp(
        dark ? const Color(0xFF363D49) : Colors.white,
        color,
        dark ? .35 : .13,
      )!,
      ink: dark ? const Color(0xFFF3F4F6) : const Color(0xFF192433),
      muted: dark ? const Color(0xFFBDC5D4) : const Color(0xFF647085),
    );
  }
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? appPalettes.first;

  @override
  AppPalette copyWith({
    String? name,
    Color? accent,
    Color? background,
    Color? surface,
    Color? soft,
    Color? border,
    Color? heroStart,
    Color? heroEnd,
    Color? ink,
    Color? muted,
    Color? onAccent,
  }) => AppPalette(
    name: name ?? this.name,
    accent: accent ?? this.accent,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    soft: soft ?? this.soft,
    border: border ?? this.border,
    heroStart: heroStart ?? this.heroStart,
    heroEnd: heroEnd ?? this.heroEnd,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      name: t < .5 ? name : other.name,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      border: Color.lerp(border, other.border, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

const appPalettes = [
  AppPalette(
    name: 'White',
    accent: Color(0xFF253248),
    background: Colors.white,
    surface: Color(0xFFF7F8FA),
    soft: Color(0xFFEBEEF2),
    border: Color(0xFFDFE4EA),
    heroStart: Color(0xFFEFF2F5),
    heroEnd: Color(0xFFEFF2F5),
  ),
  AppPalette(
    name: 'Pink',
    accent: Color(0xFFD6336C),
    background: Color(0xFFFFF3F7),
    surface: Color(0xFFFFFBFD),
    soft: Color(0xFFFAD5E2),
    border: Color(0xFFF1BCD0),
    heroStart: Color(0xFFFFC5D8),
    heroEnd: Color(0xFFFFE4ED),
    ink: Color(0xFF442235),
  ),
  AppPalette(
    name: 'Lavender',
    accent: Color(0xFF7652B6),
    background: Color(0xFFF3EFFF),
    surface: Color(0xFFFBF9FF),
    soft: Color(0xFFE8DFF9),
    border: Color(0xFFD3C3EF),
    heroStart: Color(0xFFDAC7F3),
    heroEnd: Color(0xFFEDE5FF),
    ink: Color(0xFF2D2344),
  ),
  AppPalette(
    name: 'Teal',
    accent: Color(0xFF007F74),
    background: Color(0xFFEDF9F6),
    surface: Color(0xFFF7FFFC),
    soft: Color(0xFFD4F0E9),
    border: Color(0xFFB2DCD1),
    heroStart: Color(0xFFBFEADF),
    heroEnd: Color(0xFFDCF7EF),
    ink: Color(0xFF183C36),
  ),
  AppPalette(
    name: 'Blue',
    accent: Color(0xFF2463D6),
    background: Color(0xFFEFF5FF),
    surface: Color(0xFFF8FBFF),
    soft: Color(0xFFDAE8FF),
    border: Color(0xFFBFD3F5),
    heroStart: Color(0xFFC3D8FF),
    heroEnd: Color(0xFFE2EDFF),
    ink: Color(0xFF1C2D49),
  ),
  AppPalette(
    name: 'Amber',
    accent: Color(0xFF9A5800),
    background: Color(0xFFFFF7E8),
    surface: Color(0xFFFFFCF5),
    soft: Color(0xFFF8E6C2),
    border: Color(0xFFE8D1A5),
    heroStart: Color(0xFFF3D59D),
    heroEnd: Color(0xFFFFF0CD),
    ink: Color(0xFF46331C),
  ),
  AppPalette(
    name: 'Black',
    accent: Color(0xFFD9DEE7),
    onAccent: Color(0xFF111317),
    background: Color(0xFF101214),
    surface: Color(0xFF1A1D23),
    soft: Color(0xFF2A2E36),
    border: Color(0xFF3A404C),
    heroStart: Color(0xFF252A34),
    heroEnd: Color(0xFF363D49),
    ink: Color(0xFFF3F4F6),
    muted: Color(0xFFBDC5D4),
  ),
  AppPalette(
    name: 'Brown',
    accent: Color(0xFF75462F),
    background: Color(0xFFF6EEE7),
    surface: Color(0xFFFFFAF5),
    soft: Color(0xFFE8D7CA),
    border: Color(0xFFCEB5A4),
    heroStart: Color(0xFFDDC0A9),
    heroEnd: Color(0xFFEDDDCE),
    ink: Color(0xFF3A261C),
  ),
];

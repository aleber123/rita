import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'freehand_stroke.dart';

/// Two-row palette: solid colors on top, premium pens below. Premium pens
/// are always rendered (so kids see what's behind the lock) — locked pens
/// show a small lock badge and route taps to [onLockedPremiumTap] instead
/// of selecting them.
class ColorPalette extends StatelessWidget {
  final List<Color> solidColors;
  final Color selectedColor;
  final BrushKind selectedKind;
  final bool premiumUnlocked;
  final ValueChanged<Color> onSelectSolid;
  final ValueChanged<BrushKind> onSelectPremium;
  final VoidCallback onLockedPremiumTap;

  const ColorPalette({
    super.key,
    required this.solidColors,
    required this.selectedColor,
    required this.selectedKind,
    required this.premiumUnlocked,
    required this.onSelectSolid,
    required this.onSelectPremium,
    required this.onLockedPremiumTap,
  });

  static const List<BrushKind> _premiumKinds = [
    BrushKind.rainbow,
    BrushKind.glitter,
    BrushKind.neon,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: solidColors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = solidColors[i];
              final isSelected = selectedKind == BrushKind.solid &&
                  c.toARGB32() == selectedColor.toARGB32();
              return GestureDetector(
                onTap: () => onSelectSolid(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isSelected ? 64 : 56,
                  height: isSelected ? 64 : 56,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.black26,
                      width: isSelected ? 4 : 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final kind in _premiumKinds) ...[
                _PremiumSwatch(
                  kind: kind,
                  isSelected: selectedKind == kind,
                  locked: !premiumUnlocked,
                  onTap: () {
                    if (premiumUnlocked) {
                      onSelectPremium(kind);
                    } else {
                      onLockedPremiumTap();
                    }
                  },
                ),
                if (kind != _premiumKinds.last) const SizedBox(width: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumSwatch extends StatelessWidget {
  final BrushKind kind;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;

  const _PremiumSwatch({
    required this.kind,
    required this.isSelected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 60.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.black26,
                    width: isSelected ? 4 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: CustomPaint(
                    painter: _PremiumSwatchPainter(kind),
                  ),
                ),
              ),
              if (locked)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumSwatchPainter extends CustomPainter {
  final BrushKind kind;
  _PremiumSwatchPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case BrushKind.rainbow:
        _paintRainbow(canvas, size);
        break;
      case BrushKind.glitter:
        _paintGlitter(canvas, size);
        break;
      case BrushKind.neon:
        _paintNeon(canvas, size);
        break;
      case BrushKind.solid:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Colors.white,
        );
        break;
    }
  }

  void _paintRainbow(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFF0000),
      Color(0xFFFFA500),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00BFFF),
      Color(0xFF8A2BE2),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const SweepGradient(colors: colors).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintGlitter(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFD700),
    );
    final rng = math.Random(42);
    final sparkle = Paint()..color = Colors.white;
    for (var i = 0; i < 14; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 1.2 + rng.nextDouble() * 1.8;
      canvas.drawCircle(Offset(cx, cy), r, sparkle);
    }
  }

  void _paintNeon(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFF1493),
    );
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.18,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      size.shortestSide * 0.1,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumSwatchPainter old) => old.kind != kind;
}

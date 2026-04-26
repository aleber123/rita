import 'package:flutter/material.dart';

enum BrushKind { solid, rainbow, glitter, neon }

/// One freehand stroke. Points are stored normalized to canvas size [0..1]
/// so strokes survive layout changes and pinch-zoom.
class FreehandStroke {
  final Color color;
  final double width;
  final List<Offset> points;
  final BrushKind kind;

  const FreehandStroke({
    required this.color,
    required this.width,
    required this.points,
    this.kind = BrushKind.solid,
  });

  FreehandStroke copyWith({List<Offset>? points}) => FreehandStroke(
        color: color,
        width: width,
        points: points ?? this.points,
        kind: kind,
      );
}

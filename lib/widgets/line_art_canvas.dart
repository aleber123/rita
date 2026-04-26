import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'freehand_stroke.dart';

/// Coloring canvas for any black-on-white line art (bundled asset PNG or
/// edge-detected photo bytes). The image renders as a `multiply` overlay
/// so freehand strokes drawn underneath show through where the line art
/// is white. No tap-fill — only freehand drawing.
class LineArtCanvas extends StatefulWidget {
  final ImageProvider imageProvider;
  final List<FreehandStroke> strokes;
  final double strokeWidth;
  final void Function(Offset normalized) onFreehandStart;
  final void Function(Offset normalized) onFreehandUpdate;
  final VoidCallback? onFreehandEnd;

  const LineArtCanvas({
    super.key,
    required this.imageProvider,
    required this.strokes,
    required this.onFreehandStart,
    required this.onFreehandUpdate,
    this.onFreehandEnd,
    this.strokeWidth = 12,
  });

  @override
  State<LineArtCanvas> createState() => _LineArtCanvasState();
}

class _LineArtCanvasState extends State<LineArtCanvas> {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  final Set<int> _activePointers = {};
  int? _drawingPointer;

  @override
  void initState() {
    super.initState();
    _resolve(widget.imageProvider);
  }

  @override
  void didUpdateWidget(covariant LineArtCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _resolve(widget.imageProvider);
    }
  }

  void _resolve(ImageProvider provider) {
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          info.image.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = info.image.clone();
        });
      },
      onError: (e, _) => debugPrint('[LineArtCanvas] decode failed: $e'),
    );
    _stream?.removeListener(_listener!);
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _image?.dispose();
    super.dispose();
  }

  Offset _normalize(Offset p, Size s) =>
      Offset(p.dx / s.width, p.dy / s.height);

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final aspect = image.width / image.height;
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return InteractiveViewer(
            panEnabled: false,
            minScale: 1.0,
            maxScale: 4.0,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) {
                _activePointers.add(e.pointer);
                if (_activePointers.length > 1) {
                  _drawingPointer = null;
                  return;
                }
                _drawingPointer = e.pointer;
                widget.onFreehandStart(_normalize(e.localPosition, size));
              },
              onPointerMove: (e) {
                if (_activePointers.length > 1) return;
                if (e.pointer != _drawingPointer) return;
                widget.onFreehandUpdate(_normalize(e.localPosition, size));
              },
              onPointerUp: (e) {
                _activePointers.remove(e.pointer);
                if (e.pointer == _drawingPointer) {
                  _drawingPointer = null;
                  widget.onFreehandEnd?.call();
                }
              },
              onPointerCancel: (e) {
                _activePointers.remove(e.pointer);
                if (e.pointer == _drawingPointer) {
                  _drawingPointer = null;
                  widget.onFreehandEnd?.call();
                }
              },
              child: CustomPaint(
                size: size,
                painter: _LineArtPainter(
                  image: image,
                  strokes: widget.strokes,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LineArtPainter extends CustomPainter {
  final ui.Image image;
  final List<FreehandStroke> strokes;

  final int _strokeCount;
  final int _lastStrokePointCount;
  final int? _lastStrokeColorValue;

  _LineArtPainter({required this.image, required this.strokes})
      : _strokeCount = strokes.length,
        _lastStrokePointCount =
            strokes.isEmpty ? 0 : strokes.last.points.length,
        _lastStrokeColorValue =
            strokes.isEmpty ? null : strokes.last.color.toARGB32();

  @override
  void paint(ui.Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      switch (s.kind) {
        case BrushKind.solid:
          _paintSolid(canvas, s, size);
          break;
        case BrushKind.rainbow:
          _paintRainbow(canvas, s, size);
          break;
        case BrushKind.glitter:
          _paintGlitter(canvas, s, size);
          break;
        case BrushKind.neon:
          _paintNeon(canvas, s, size);
          break;
      }
    }

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..blendMode = BlendMode.multiply,
    );
  }

  void _paintSolid(ui.Canvas canvas, FreehandStroke s, Size size) {
    final paint = Paint()
      ..color = s.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final first = s.points.first;
    final p0 = Offset(first.dx * size.width, first.dy * size.height);
    if (s.points.length == 1) {
      canvas.drawCircle(p0, s.width / 2, Paint()..color = s.color);
      return;
    }
    final path = Path()..moveTo(p0.dx, p0.dy);
    for (var i = 1; i < s.points.length; i++) {
      final p = s.points[i];
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    canvas.drawPath(path, paint);
  }

  void _paintRainbow(ui.Canvas canvas, FreehandStroke s, Size size) {
    final first = s.points.first;
    final p0 = Offset(first.dx * size.width, first.dy * size.height);
    if (s.points.length == 1) {
      canvas.drawCircle(
        p0,
        s.width / 2,
        Paint()..color = HSVColor.fromAHSV(1, 0, 0.85, 1).toColor(),
      );
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final n = s.points.length;
    var prev = p0;
    for (var i = 1; i < n; i++) {
      final pn = s.points[i];
      final p = Offset(pn.dx * size.width, pn.dy * size.height);
      final t = i / (n - 1);
      paint.color = HSVColor.fromAHSV(1, (t * 360) % 360, 0.85, 1).toColor();
      canvas.drawLine(prev, p, paint);
      prev = p;
    }
  }

  void _paintGlitter(ui.Canvas canvas, FreehandStroke s, Size size) {
    final base = const Color(0xFFFFD700);
    final paint = Paint()
      ..color = base
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final first = s.points.first;
    final p0 = Offset(first.dx * size.width, first.dy * size.height);
    if (s.points.length == 1) {
      canvas.drawCircle(p0, s.width / 2, Paint()..color = base);
    } else {
      final path = Path()..moveTo(p0.dx, p0.dy);
      for (var i = 1; i < s.points.length; i++) {
        final p = s.points[i];
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
    final rng = math.Random(s.points.length * 31 + s.color.toARGB32());
    final sparkle = Paint()..color = Colors.white;
    final radius = s.width * 0.18;
    for (var i = 0; i < s.points.length; i++) {
      if (rng.nextDouble() > 0.45) continue;
      final p = s.points[i];
      final cx = p.dx * size.width + (rng.nextDouble() - 0.5) * s.width;
      final cy = p.dy * size.height + (rng.nextDouble() - 0.5) * s.width;
      canvas.drawCircle(Offset(cx, cy), radius, sparkle);
    }
  }

  void _paintNeon(ui.Canvas canvas, FreehandStroke s, Size size) {
    final glow = const Color(0xFFFF1493);
    final glowPaint = Paint()
      ..color = glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.6);
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final first = s.points.first;
    final p0 = Offset(first.dx * size.width, first.dy * size.height);
    if (s.points.length == 1) {
      canvas.drawCircle(p0, s.width / 2, glowPaint);
      canvas.drawCircle(p0, s.width * 0.25, corePaint);
      return;
    }
    final path = Path()..moveTo(p0.dx, p0.dy);
    for (var i = 1; i < s.points.length; i++) {
      final p = s.points[i];
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant _LineArtPainter old) {
    if (old.image != image) return true;
    if (old._strokeCount != _strokeCount) return true;
    if (old._lastStrokePointCount != _lastStrokePointCount) return true;
    if (old._lastStrokeColorValue != _lastStrokeColorValue) return true;
    return false;
  }
}

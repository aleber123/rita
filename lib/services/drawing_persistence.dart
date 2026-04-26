import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path_provider/path_provider.dart';

import '../widgets/freehand_stroke.dart';

class DrawingState {
  final List<FreehandStroke> strokes;
  const DrawingState({this.strokes = const []});
  bool get isEmpty => strokes.isEmpty;
}

/// Persists per-drawing freehand strokes to
/// `{appdocs}/rita_drawings/{id}.json`.
class DrawingPersistence {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/rita_drawings');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<DrawingState> load(String id) async {
    try {
      final dir = await _dir();
      final jsonFile = File('${dir.path}/$id.json');
      if (!await jsonFile.exists()) return const DrawingState();

      final raw = await jsonFile.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final strokes = (data['strokes'] as List<dynamic>? ?? const [])
          .map((e) => _strokeFromJson(e as Map<String, dynamic>))
          .toList();
      return DrawingState(strokes: strokes);
    } catch (e) {
      debugPrint('[DrawingPersistence] load failed for $id: $e');
      return const DrawingState();
    }
  }

  static Future<void> save(
    String id, {
    required List<FreehandStroke> strokes,
  }) async {
    try {
      final dir = await _dir();
      final jsonFile = File('${dir.path}/$id.json');
      final data = <String, dynamic>{
        'strokes': strokes.map(_strokeToJson).toList(),
      };
      await jsonFile.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[DrawingPersistence] save failed for $id: $e');
    }
  }

  static Future<void> clear(String id) async {
    try {
      final dir = await _dir();
      final jsonFile = File('${dir.path}/$id.json');
      if (await jsonFile.exists()) await jsonFile.delete();
    } catch (e) {
      debugPrint('[DrawingPersistence] clear failed for $id: $e');
    }
  }

  static Map<String, dynamic> _strokeToJson(FreehandStroke s) => {
        'color': s.color.toARGB32(),
        'width': s.width,
        'kind': s.kind.index,
        'points':
            s.points.expand((o) => [o.dx, o.dy]).toList(growable: false),
      };

  static FreehandStroke _strokeFromJson(Map<String, dynamic> j) {
    final flat = (j['points'] as List<dynamic>).cast<num>();
    final points = <Offset>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      points.add(Offset(flat[i].toDouble(), flat[i + 1].toDouble()));
    }
    final kindIndex = (j['kind'] as int?) ?? 0;
    final kind = kindIndex >= 0 && kindIndex < BrushKind.values.length
        ? BrushKind.values[kindIndex]
        : BrushKind.solid;
    return FreehandStroke(
      color: Color(j['color'] as int),
      width: (j['width'] as num).toDouble(),
      points: points,
      kind: kind,
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/modules_catalog.dart';
import '../models/drawing.dart';
import '../services/drawing_persistence.dart';
import '../services/module_service.dart';
import '../utils/app_theme.dart';
import '../widgets/color_palette.dart';
import '../widgets/freehand_stroke.dart';
import '../widgets/line_art_canvas.dart';
import '../widgets/parental_gate.dart';

class ColoringScreen extends StatefulWidget {
  final Drawing drawing;
  const ColoringScreen({super.key, required this.drawing});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen>
    with WidgetsBindingObserver {
  static const List<Color> _palette = [
    Color(0xFFE63946),
    Color(0xFFF4A261),
    Color(0xFFFFD166),
    Color(0xFF8AC926),
    Color(0xFF48CAE4),
    Color(0xFF9D4EDD),
    Color(0xFFFF6B9D),
    Color(0xFF6B4423),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];

  final GlobalKey _captureKey = GlobalKey();

  Color _selected = const Color(0xFFE63946);
  BrushKind _selectedKind = BrushKind.solid;
  final List<FreehandStroke> _strokes = [];
  bool _saving = false;

  final List<VoidCallback> _undoStack = [];
  static const int _maxUndo = 30;

  void _pushUndo(VoidCallback undo) {
    _undoStack.add(undo);
    if (_undoStack.length > _maxUndo) {
      _undoStack.removeAt(0);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    final state = await DrawingPersistence.load(widget.drawing.id);
    if (!mounted || state.isEmpty) return;
    setState(() {
      _strokes
        ..clear()
        ..addAll(state.strokes);
    });
  }

  Future<void> _persist() async {
    await DrawingPersistence.save(
      widget.drawing.id,
      strokes: List<FreehandStroke>.from(_strokes),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persist();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persist();
    super.dispose();
  }

  void _onFreehandStart(Offset normalized) {
    _pushUndo(() {
      if (_strokes.isEmpty) return;
      setState(() => _strokes.removeLast());
    });
    setState(() {
      _strokes.add(FreehandStroke(
        color: _selected,
        width: 12,
        points: [normalized],
        kind: _selectedKind,
      ));
    });
  }

  Future<void> _onLockedPremiumTap() async {
    final service = context.read<ModuleService>();
    final ok = await ParentalGate.show(context);
    if (!ok || !mounted) return;
    await service.purchase(ModulesCatalog.magicPensProductId);
  }

  void _onFreehandUpdate(Offset normalized) {
    if (_strokes.isEmpty) return;
    setState(() {
      final last = _strokes.last;
      _strokes[_strokes.length - 1] =
          last.copyWith(points: [...last.points, normalized]);
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    action();
  }

  bool get _hasContent => _strokes.isNotEmpty;
  bool get _canUndo => _undoStack.isNotEmpty;

  Future<void> _shareDrawing(BuildContext shareButtonContext) async {
    if (_saving) return;
    final pixelRatio =
        MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Hittade inte ritytan');
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Kunde inte koda PNG');
      }
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/rita_${widget.drawing.id}_$ts.png');
      await file.writeAsBytes(bytes, flush: true);

      Rect? origin;
      final box = shareButtonContext.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'image/png',
            name: 'rita_${widget.drawing.id}.png',
          ),
        ],
        text: 'Min teckning av ${widget.drawing.title} 🎨',
        subject: 'Min teckning',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte dela: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(widget.drawing.title),
        actions: [
          _BigActionButton(
            tooltip: 'Ångra',
            icon: Icons.undo_rounded,
            onPressed: _canUndo ? _undo : null,
          ),
          Builder(
            builder: (btnCtx) => _BigActionButton(
              tooltip: 'Dela',
              icon: Icons.ios_share_rounded,
              loading: _saving,
              onPressed: _hasContent && !_saving
                  ? () => _shareDrawing(btnCtx)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  key: _captureKey,
                  child: LineArtCanvas(
                    imageProvider: AssetImage(widget.drawing.assetPath),
                    strokes: _strokes,
                    onFreehandStart: _onFreehandStart,
                    onFreehandUpdate: _onFreehandUpdate,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Rita med fingret · nyp för att zooma',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
            Consumer<ModuleService>(
              builder: (context, service, _) {
                final unlocked =
                    service.isUnlocked(ModulesCatalog.magicPensProductId);
                return ColorPalette(
                  solidColors: _palette,
                  selectedColor: _selected,
                  selectedKind: _selectedKind,
                  premiumUnlocked: unlocked,
                  onSelectSolid: (c) => setState(() {
                    _selected = c;
                    _selectedKind = BrushKind.solid;
                  }),
                  onSelectPremium: (k) =>
                      setState(() => _selectedKind = k),
                  onLockedPremiumTap: _onLockedPremiumTap,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  const _BigActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final iconColor =
        enabled ? AppTheme.ink : AppTheme.ink.withValues(alpha: 0.3);
    final bg = enabled
        ? AppTheme.sunny
        : AppTheme.sunny.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          shape: const CircleBorder(
            side: BorderSide(color: AppTheme.ink, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(icon, size: 32, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

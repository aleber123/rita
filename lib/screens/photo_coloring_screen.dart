import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/modules_catalog.dart';
import '../services/edge_detector.dart';
import '../services/module_service.dart';
import '../utils/app_theme.dart';
import '../widgets/color_palette.dart';
import '../widgets/freehand_stroke.dart';
import '../widgets/line_art_canvas.dart';
import '../widgets/parental_gate.dart';

/// Lets the user pick or take a photo, runs on-device edge detection on
/// it, and renders the result as a coloring page the kid can fill in
/// freehand. No AI, no network — pure pixel math.
class PhotoColoringScreen extends StatefulWidget {
  const PhotoColoringScreen({super.key});

  @override
  State<PhotoColoringScreen> createState() => _PhotoColoringScreenState();
}

class _PhotoColoringScreenState extends State<PhotoColoringScreen> {
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
  final ImagePicker _picker = ImagePicker();

  Uint8List? _edgeBytes;
  bool _processing = false;
  String? _error;

  Color _selected = const Color(0xFFE63946);
  BrushKind _selectedKind = BrushKind.solid;
  final List<FreehandStroke> _strokes = [];
  final List<VoidCallback> _undoStack = [];
  bool _saving = false;

  static const int _maxUndo = 30;

  Future<void> _pickAndProcess(ImageSource source) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null) {
        if (mounted) setState(() => _processing = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final edges = await EdgeDetector.processBytes(bytes);
      if (!mounted) return;
      setState(() {
        _edgeBytes = edges;
        _strokes.clear();
        _undoStack.clear();
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kunde inte bearbeta bilden: $e';
        _processing = false;
      });
    }
  }

  void _pushUndo(VoidCallback undo) {
    _undoStack.add(undo);
    if (_undoStack.length > _maxUndo) {
      _undoStack.removeAt(0);
    }
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

  void _retake() {
    setState(() {
      _edgeBytes = null;
      _strokes.clear();
      _undoStack.clear();
      _error = null;
    });
  }

  Future<void> _share(BuildContext shareButtonContext) async {
    if (_saving || _edgeBytes == null) return;
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
      final file = File('${dir.path}/rita_kort_$ts.png');
      await file.writeAsBytes(bytes, flush: true);

      Rect? origin;
      final box = shareButtonContext.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'rita_kort.png')],
        text: 'Min teckning från ett foto 🎨',
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
    final unlocked = context
        .watch<ModuleService>()
        .isUnlocked(ModulesCatalog.photoProductId);
    if (!unlocked) {
      return Scaffold(
        backgroundColor: AppTheme.cream,
        appBar: AppBar(title: const Text('Kort till teckning')),
        body: const _PhotoLockedView(),
      );
    }
    final hasEdges = _edgeBytes != null;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text('Kort till teckning'),
        actions: hasEdges
            ? [
                _ActionButton(
                  tooltip: 'Ångra',
                  icon: Icons.undo_rounded,
                  onPressed: _undoStack.isNotEmpty ? _undo : null,
                ),
                _ActionButton(
                  tooltip: 'Ta nytt kort',
                  icon: Icons.refresh_rounded,
                  onPressed: _retake,
                ),
                Builder(
                  builder: (btnCtx) => _ActionButton(
                    tooltip: 'Dela',
                    icon: Icons.ios_share_rounded,
                    loading: _saving,
                    onPressed: _strokes.isNotEmpty && !_saving
                        ? () => _share(btnCtx)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: _buildBody())),
            if (hasEdges) ...[
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
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_processing) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Förvandlar fotot...',
              style: TextStyle(color: Colors.black54)),
        ],
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _error = null),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    final bytes = _edgeBytes;
    if (bytes == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_camera_rounded,
                size: 96, color: AppTheme.sky),
            const SizedBox(height: 16),
            const Text(
              'Ta ett kort eller välj från galleriet —\nappen gör om det till en målarbild!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 32),
            _ChoiceButton(
              icon: Icons.photo_camera_rounded,
              label: 'Ta kort',
              onPressed: () => _pickAndProcess(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _ChoiceButton(
              icon: Icons.photo_library_rounded,
              label: 'Välj från galleri',
              onPressed: () => _pickAndProcess(ImageSource.gallery),
            ),
          ],
        ),
      );
    }
    return RepaintBoundary(
      key: _captureKey,
      child: LineArtCanvas(
        imageProvider: MemoryImage(bytes),
        strokes: _strokes,
        onFreehandStart: _onFreehandStart,
        onFreehandUpdate: _onFreehandUpdate,
      ),
    );
  }
}

class _PhotoLockedView extends StatelessWidget {
  const _PhotoLockedView();

  Future<void> _onUnlock(BuildContext context) async {
    final service = context.read<ModuleService>();
    final ok = await ParentalGate.show(context);
    if (!ok || !context.mounted) return;
    await service.purchase(ModulesCatalog.photoProductId);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ModuleService>();
    final price = service.priceFor(
      ModulesCatalog.photoProductId,
      fallback: '29 kr',
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📸', style: TextStyle(fontSize: 96)),
          const SizedBox(height: 16),
          const Text(
            'Förvandla ett kort',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ta ett foto eller välj från galleriet —\nappen gör om det till en målarbild att färglägga.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  service.purchasing ? null : () => _onUnlock(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.berry,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: service.purchasing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Lås upp för $price',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: service.purchasing
                ? null
                : () async {
                    final ok = await ParentalGate.show(context);
                    if (!ok) return;
                    await service.restore();
                  },
            child: const Text('Återställ köp'),
          ),
          if (service.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Något gick fel. Försök igen.',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.sunny,
          foregroundColor: AppTheme.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: AppTheme.ink, width: 2),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  const _ActionButton({
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

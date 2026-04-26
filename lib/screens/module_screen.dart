import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/drawing.dart';
import '../models/module.dart';
import '../services/module_service.dart';
import '../utils/app_theme.dart';
import '../widgets/parental_gate.dart';
import 'coloring_screen.dart';

class ModuleScreen extends StatelessWidget {
  final DrawingModule module;
  const ModuleScreen({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: Text('${module.emoji}  ${module.title}'),
      ),
      body: Consumer<ModuleService>(
        builder: (context, service, _) {
          final unlocked = service.isUnlocked(module.productId);
          if (!unlocked) {
            return _LockedView(module: module, service: service);
          }
          if (module.drawings.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Teckningar kommer snart',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.9,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: module.drawings.length,
            itemBuilder: (_, i) {
              final d = module.drawings[i];
              return _DrawingCard(
                drawing: d,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ColoringScreen(drawing: d),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  final DrawingModule module;
  final ModuleService service;

  const _LockedView({required this.module, required this.service});

  Future<void> _onUnlock(BuildContext context) async {
    final ok = await ParentalGate.show(context);
    if (!ok || !context.mounted) return;
    if (module.productId == null) return;
    await service.purchase(module.productId!);
  }

  @override
  Widget build(BuildContext context) {
    final price = module.productId == null
        ? ''
        : service.priceFor(module.productId!);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(module.emoji, style: const TextStyle(fontSize: 96)),
          const SizedBox(height: 16),
          Text(
            module.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lås upp paketet för obegränsad färgläggning.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: service.purchasing ? null : () => _onUnlock(context),
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
                      price.isEmpty ? 'Lås upp' : 'Lås upp för $price',
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

class _DrawingCard extends StatelessWidget {
  final Drawing drawing;
  final VoidCallback onTap;

  const _DrawingCard({required this.drawing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  drawing.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.brush_rounded,
                      size: 56,
                      color: AppTheme.sky,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              drawing.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

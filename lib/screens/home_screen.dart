import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/modules_catalog.dart';
import '../models/module.dart';
import '../services/module_service.dart';
import '../utils/app_theme.dart';
import 'module_screen.dart';
import 'paywall_screen.dart';
import 'photo_coloring_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Rita',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                  letterSpacing: -1,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Välj något att färglägga',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            Consumer<ModuleService>(
              builder: (context, service, _) =>
                  _PremiumBanner(service: service),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Consumer<ModuleService>(
                builder: (context, service, _) {
                  final modules = ModulesCatalog.all;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: modules.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _PhotoCard(service: service);
                      }
                      final m = modules[i - 1];
                      return _ModuleCard(
                        module: m,
                        unlocked: service.isUnlocked(m.productId),
                        priceLabel: m.productId == null
                            ? null
                            : service.priceFor(m.productId!),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ModuleScreen(module: m),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final ModuleService service;
  const _PhotoCard({required this.service});

  static const List<Color> _colors = [
    Color(0xFF48CAE4),
    Color(0xFF1B4965),
  ];

  void _onTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhotoColoringScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = service.isUnlocked(ModulesCatalog.photoProductId);
    final priceLabel = service.priceFor(
      ModulesCatalog.photoProductId,
      fallback: '29 kr',
    );
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: _colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _colors.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📸', style: TextStyle(fontSize: 48)),
                const Spacer(),
                const Text(
                  'Förvandla ett kort',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                if (unlocked)
                  const Text(
                    'Foto till färgläggning',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  )
                else
                  Text(
                    priceLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            if (!unlocked)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.lock, color: Colors.white, size: 24),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final DrawingModule module;
  final bool unlocked;
  final String? priceLabel;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.unlocked,
    required this.priceLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _moduleColors(module.id);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                const Spacer(),
                Text(
                  module.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                if (unlocked)
                  Text(
                    '${module.drawings.length} teckningar',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  )
                else if (priceLabel != null)
                  Text(
                    priceLabel!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            if (!unlocked && module.productId != null)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.lock, color: Colors.white, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  List<Color> _moduleColors(String id) {
    switch (id) {
      case 'free':
        return [const Color(0xFFFFC857), const Color(0xFFFF8FA3)];
      case 'unicorns':
        return [const Color(0xFFFF6B9D), const Color(0xFF9D4EDD)];
      case 'superheroes':
        return [const Color(0xFF1B4965), const Color(0xFF5FA8D3)];
      case 'animals':
        return [const Color(0xFF8AC926), const Color(0xFF52B788)];
      case 'vehicles':
        return [const Color(0xFFE63946), const Color(0xFFF4A261)];
      case 'dinosaurs':
        return [const Color(0xFF386641), const Color(0xFF6A994E)];
    }
    return [const Color(0xFFFFC857), const Color(0xFF63B4D1)];
  }
}

class _PremiumBanner extends StatelessWidget {
  final ModuleService service;
  const _PremiumBanner({required this.service});

  @override
  Widget build(BuildContext context) {
    final active = service.hasActiveSubscription;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaywallScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? const [Color(0xFF8AC926), Color(0xFF52B788)]
                  : const [Color(0xFFFF6B9D), Color(0xFF9D4EDD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (active ? AppTheme.leaf : AppTheme.berry)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                active ? '✨' : '🔓',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Premium aktiv' : 'Lås upp allt',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? 'Alla teckningar är upplåsta'
                          : 'Alla moduler — månad eller år',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

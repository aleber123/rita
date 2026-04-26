import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/premium_service.dart';
import '../services/sleep_database_service.dart';
import '../utils/app_theme.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    final db = context.read<SleepDatabaseService>();
    if (!db.loaded) await db.load();
    if (mounted) setState(() => _loaded = true);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<SleepDatabaseService>();
    final premium = context.watch<PremiumService>();
    final scheme = Theme.of(context).colorScheme;
    final favorites = _loaded ? db.favoriteClips() : [];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceDark, const Color(0xFF1A1F3D)],
          ),
        ),
        child: SafeArea(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Profil',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PremiumCard(premium: premium, accent: scheme.primary),
                    const SizedBox(height: 16),
                    _StatsCard(
                      nights: db.totalNights,
                      avgQuality: db.averageQualityPercent,
                      avgInBed: _fmt(db.averageInBed),
                      accent: scheme.primary,
                    ),
                    const SizedBox(height: 16),
                    _FavoritesSection(
                        clips: favorites.cast(), accent: scheme.primary),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final PremiumService premium;
  final Color accent;
  const _PremiumCard({required this.premium, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isPremium = premium.isPremium;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [accent.withValues(alpha: 0.4), accent.withValues(alpha: 0.18)]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.lock_outline_rounded,
            color: accent,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Sömnkoll Premium' : 'Lås upp Premium',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'Alla funktioner är aktiva'
                      : 'All historik, ljudklipp & avancerad analys',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium)
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaywallScreen(source: 'profile'),
                ),
              ),
              child: const Text('Uppgradera'),
            ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int nights;
  final int avgQuality;
  final String avgInBed;
  final Color accent;
  const _StatsCard({
    required this.nights,
    required this.avgQuality,
    required this.avgInBed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Din sömn-statistik',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white),
          ),
          const SizedBox(height: 12),
          _row(Icons.calendar_today_rounded, 'Nätter spårade', '$nights'),
          const SizedBox(height: 8),
          _row(Icons.auto_graph_rounded, 'Snitt-kvalitet', '$avgQuality%'),
          const SizedBox(height: 8),
          _row(Icons.bed_rounded, 'Snitt i säng', avgInBed),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  final List clips;
  final Color accent;
  const _FavoritesSection({required this.clips, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              const Text('Sparade ljudklipp',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white)),
              const Spacer(),
              Text('${clips.length} st',
                  style: const TextStyle(color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 8),
          if (clips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Markera ljudklipp som favoriter i en natts detaljer för att hitta dem här.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            )
          else
            for (final c in clips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(c.kind.emoji,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.kind.label,
                              style: const TextStyle(color: Colors.white)),
                          Text(
                            DateFormat('d MMM HH:mm', 'sv').format(c.recordedAt),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text('${(c.durationMs / 1000).toStringAsFixed(0)}s',
                        style: const TextStyle(color: Colors.white60)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

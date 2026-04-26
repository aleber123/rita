import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sleep_session.dart';
import '../services/premium_service.dart';
import '../services/sleep_database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/sleep_phase_chart.dart';
import 'paywall_screen.dart';
import 'session_detail_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
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

  @override
  Widget build(BuildContext context) {
    final db = context.watch<SleepDatabaseService>();
    final premium = context.watch<PremiumService>();
    final sessions = db.sessions;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceDark,
              const Color(0xFF1A1F3D),
            ],
          ),
        ),
        child: SafeArea(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : sessions.isEmpty
                  ? _Empty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: sessions.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 16, left: 4),
                            child: Text(
                              'Journal',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        final idx = i - 1;
                        final session = sessions[idx];
                        final locked = !premium.canViewSession(idx);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NightCard(
                            session: session,
                            locked: locked,
                            onTap: () {
                              if (locked) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PaywallScreen(source: 'journal'),
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SessionDetailScreen(session: session),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 64, color: scheme.primary),
          const SizedBox(height: 16),
          const Text('Inga nätter ännu',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
          const SizedBox(height: 8),
          Text(
            'Tryck på "Starta" på sömnfliken för att börja spåra din första natt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NightCard extends StatelessWidget {
  final SleepSession session;
  final bool locked;
  final VoidCallback onTap;

  const _NightCard({
    required this.session,
    required this.locked,
    required this.onTap,
  });

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('EEE d MMM', 'sv');
    final timeFmt = DateFormat.Hm('sv');

    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _capitalize(dateFmt.format(session.bedTime)),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (locked)
                    Icon(Icons.lock_rounded,
                        size: 18, color: scheme.primary)
                  else
                    Text(
                      '${session.qualityPercent}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${timeFmt.format(session.bedTime)} – ${timeFmt.format(session.wakeTime)} • ${_fmt(session.totalInBed)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: locked
                    ? _LockedBlur(scheme: scheme)
                    : SleepPhaseChart(
                        phases: session.phases,
                        bedTime: session.bedTime,
                        wakeTime: session.wakeTime,
                        color: scheme.primary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _LockedBlur extends StatelessWidget {
  final ColorScheme scheme;
  const _LockedBlur({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded,
                color: scheme.primary, size: 18),
            const SizedBox(width: 6),
            const Text('Lås upp äldre nätter',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

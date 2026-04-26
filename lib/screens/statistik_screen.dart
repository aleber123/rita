import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sleep_session.dart';
import '../services/sleep_database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/affiliate_tools_card.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
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
    final scheme = Theme.of(context).colorScheme;

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
                    const Text(
                      'Statistik',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SummaryRow(db: db),
                    const SizedBox(height: 16),
                    _QualityBars(
                        sessions: db.recent(limit: 14), accent: scheme.primary),
                    const SizedBox(height: 16),
                    _Regularity(
                        sessions: db.recent(limit: 14), accent: scheme.primary),
                    const SizedBox(height: 16),
                    AffiliateToolsCard(
                      accent: scheme.primary,
                      tag: db.averageQualityPercent < 60
                          ? 'mattress'
                          : 'aroma',
                      title: 'Sov bättre med rätt prylar',
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final SleepDatabaseService db;
  const _SummaryRow({required this.db});

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Snitt-kvalitet',
            value: '${db.averageQualityPercent}%',
            icon: Icons.auto_graph_rounded,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Snitt i säng',
            value: _fmt(db.averageInBed),
            icon: Icons.bed_rounded,
            color: Colors.lightBlueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Nätter',
            value: '${db.totalNights}',
            icon: Icons.calendar_today_rounded,
            color: Colors.purpleAccent,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QualityBars extends StatelessWidget {
  final List<SleepSession> sessions;
  final Color accent;
  const _QualityBars({required this.sessions, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return _Card(
        title: 'Sömnkvalitet',
        subtitle: 'Inga nätter ännu',
        child: const SizedBox(height: 80),
      );
    }
    final reversed = sessions.reversed.toList();
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < reversed.length; i++) {
      final q = reversed[i].qualityPercent.toDouble();
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: q,
              width: 14,
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.5), accent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ],
        ),
      );
    }
    return _Card(
      title: 'Sömnkvalitet',
      subtitle: 'Senaste ${reversed.length} nätter',
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            barGroups: groups,
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              show: true,
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 25,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 10)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= reversed.length) {
                      return const SizedBox.shrink();
                    }
                    final letter =
                        DateFormat('E', 'sv').format(reversed[i].bedTime);
                    return Text(
                      letter.isNotEmpty ? letter[0].toUpperCase() : '',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 10),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Regularity extends StatelessWidget {
  final List<SleepSession> sessions;
  final Color accent;
  const _Regularity({required this.sessions, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (sessions.length < 2) {
      return _Card(
        title: 'Regelbundenhet',
        subtitle: 'Behöver minst 2 nätter',
        child: const SizedBox(height: 60),
      );
    }
    final bedMins = <int>[];
    final wakeMins = <int>[];
    for (final s in sessions) {
      bedMins.add(s.bedTime.hour * 60 + s.bedTime.minute);
      wakeMins.add(s.wakeTime.hour * 60 + s.wakeTime.minute);
    }
    final bedSpread = _spreadMinutes(bedMins);
    final wakeSpread = _spreadMinutes(wakeMins);
    final score = (100 - ((bedSpread + wakeSpread) / 2).clamp(0, 100)).round();

    return _Card(
      title: 'Regelbundenhet',
      subtitle: 'Hur jämna dina läggnings- och vakentider är',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$score%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: accent,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            score >= 80
                ? 'Bra! Dina sömnvanor är stabila.'
                : score >= 50
                    ? 'OK – men du kan tjäna på mer regelbundna tider.'
                    : 'Försök hålla samma tider varje kväll och morgon.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Spread of minutes around midnight, returned in 0..100 scale (90 min stddev → 100).
  double _spreadMinutes(List<int> values) {
    if (values.length < 2) return 0;
    final wrapped = values
        .map((v) => v < 360 ? v + 24 * 60 : v) // treat early-AM as next-day
        .toList();
    final mean = wrapped.reduce((a, b) => a + b) / wrapped.length;
    final variance = wrapped
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        wrapped.length;
    final stddev = math.sqrt(variance);
    return ((stddev / 90) * 100).clamp(0, 100).toDouble();
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
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
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white,
              )),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

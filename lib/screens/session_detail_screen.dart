import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_clip.dart';
import '../models/sleep_phase.dart';
import '../models/sleep_session.dart';
import '../services/sleep_database_service.dart';
import '../widgets/affiliate_tools_card.dart';
import '../widgets/sleep_phase_chart.dart';

class SessionDetailScreen extends StatelessWidget {
  final SleepSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('EEEE d MMM', 'sv');
    final timeFmt = DateFormat.Hm('sv');
    final inBed = session.totalInBed;
    final asleep = session.totalAsleep;

    String fmt(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return '$h h $m m';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_capitalize(dateFmt.format(session.bedTime))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _QualityRing(percent: session.qualityPercent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Stat(
                          label: 'I säng',
                          value: fmt(inBed),
                          icon: Icons.bed_rounded,
                        ),
                        const SizedBox(height: 8),
                        _Stat(
                          label: 'Sömn',
                          value: fmt(asleep),
                          icon: Icons.nightlight_round,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Sömnfaser',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const Spacer(),
                      Text(
                        '${timeFmt.format(session.bedTime)} – ${timeFmt.format(session.wakeTime)}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: SleepPhaseChart(
                      phases: session.phases,
                      bedTime: session.bedTime,
                      wakeTime: session.wakeTime,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _PhasePill(
                          kind: SleepPhaseKind.awake,
                          duration: session.durationOf(SleepPhaseKind.awake)),
                      _PhasePill(
                          kind: SleepPhaseKind.light,
                          duration: session.durationOf(SleepPhaseKind.light)),
                      _PhasePill(
                          kind: SleepPhaseKind.rem,
                          duration: session.durationOf(SleepPhaseKind.rem)),
                      _PhasePill(
                          kind: SleepPhaseKind.deep,
                          duration: session.durationOf(SleepPhaseKind.deep)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (session.snoreCount > 0) _SnoreCard(session: session),
          if (session.snoreCount > 0) const SizedBox(height: 16),
          if (session.clips.isNotEmpty) _ClipsSection(session: session),
          const SizedBox(height: 16),
          AffiliateToolsCard(
            accent: scheme.primary,
            tag: session.qualityPercent < 60 ? 'mattress' : 'aroma',
            title: session.qualityPercent < 60
                ? 'Sov bättre — handplockade tips'
                : 'Behåll den goda sömnen',
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _QualityRing extends StatelessWidget {
  final int percent;
  const _QualityRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(scheme.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$percent%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  )),
              const Text('Kvalitet',
                  style: TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.white70)),
        Text(value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            )),
      ],
    );
  }
}

class _PhasePill extends StatelessWidget {
  final SleepPhaseKind kind;
  final Duration duration;
  const _PhasePill({required this.kind, required this.duration});

  Color _colorFor(SleepPhaseKind k, ColorScheme s) {
    switch (k) {
      case SleepPhaseKind.awake:
        return Colors.white.withValues(alpha: 0.6);
      case SleepPhaseKind.light:
        return Colors.lightBlueAccent;
      case SleepPhaseKind.rem:
        return Colors.purpleAccent;
      case SleepPhaseKind.deep:
        return s.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _colorFor(kind, scheme);
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('${kind.label} ${h}h ${m}m'),
      ],
    );
  }
}

class _SnoreCard extends StatelessWidget {
  final SleepSession session;
  const _SnoreCard({required this.session});

  String _intensityLabel(double db) {
    if (db >= -10) return 'Mycket högt';
    if (db >= -15) return 'Högt';
    if (db >= -20) return 'Måttligt';
    return 'Lågt';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = session.snoreSeconds / 60;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('😴',
                    style: TextStyle(
                        fontSize: 22, color: scheme.primary)),
                const SizedBox(width: 8),
                const Text(
                  'Snarkning i natt',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _intensityLabel(session.loudestSnoreDb),
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SnoreMetric(
                    icon: Icons.repeat_rounded,
                    value: '${session.snoreCount}',
                    label: 'tillfällen',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _SnoreMetric(
                    icon: Icons.timer_outlined,
                    value: minutes < 1
                        ? '${session.snoreSeconds}s'
                        : '${minutes.toStringAsFixed(0)}m',
                    label: 'totalt',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _SnoreMetric(
                    icon: Icons.graphic_eq_rounded,
                    value: '${session.loudestSnoreDb.toStringAsFixed(0)} dB',
                    label: 'topp',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Vi flaggar höga ljud (≥ -20 dBFS) under sömnfaserna som '
              'snarkning. Lyssna på klippen nedan för att verifiera.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnoreMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SnoreMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
      ],
    );
  }
}

class _ClipsSection extends StatelessWidget {
  final SleepSession session;
  const _ClipsSection({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('Inspelade ljud',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                Text('${session.clips.length} st',
                    style: const TextStyle(color: Colors.white60)),
              ],
            ),
            const SizedBox(height: 8),
            ...session.clips.map((c) => _ClipTile(clip: c)),
          ],
        ),
      ),
    );
  }
}

class _ClipTile extends StatefulWidget {
  final AudioClip clip;
  const _ClipTile({required this.clip});

  @override
  State<_ClipTile> createState() => _ClipTileState();
}

class _ClipTileState extends State<_ClipTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    final f = File(widget.clip.filePath);
    if (!f.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ljudfilen kunde inte hittas')),
      );
      return;
    }
    await _player.setFilePath(widget.clip.filePath);
    await _player.play();
    setState(() => _playing = true);
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playing = false);
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final updated = widget.clip.copyWith(favorite: !widget.clip.favorite);
    await SleepDatabaseService().updateClip(updated);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.Hm('sv');
    final c = widget.clip;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        onPressed: _toggle,
        icon: Icon(_playing
            ? Icons.pause_circle_filled_rounded
            : Icons.play_circle_fill_rounded),
        iconSize: 36,
      ),
      title: Text('${c.kind.emoji}  ${c.kind.label}'),
      subtitle: Text(
        '${fmt.format(c.recordedAt)} • ${(c.durationMs / 1000).toStringAsFixed(0)}s • ${c.peakDb.toStringAsFixed(0)} dB',
      ),
      trailing: IconButton(
        onPressed: _toggleFavorite,
        icon: Icon(c.favorite ? Icons.favorite : Icons.favorite_border),
        color: c.favorite ? Colors.redAccent : null,
      ),
    );
  }
}

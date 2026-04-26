import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_recording_service.dart';
import '../services/facebook_analytics_service.dart';
import '../services/sleep_database_service.dart';
import '../services/sleep_tracking_service.dart';
import '../utils/app_theme.dart';
import 'session_detail_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioRecordingService.instance.refreshPermissionState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = SleepTrackingService.instance.startedAt;
      if (start != null) {
        setState(() => _elapsed = DateTime.now().difference(start));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioRecordingService.instance.refreshPermissionState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avsluta natten?'),
        content: const Text('Vill du spara inspelningen och avsluta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Avbryt')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Spara')),
        ],
      ),
    );
    if (confirm != true) return;
    final session = await SleepTrackingService.instance.stop();
    if (session != null) {
      final db = context.read<SleepDatabaseService>();
      FacebookAnalyticsService.instance.logSleepSessionSaved(
        qualityPercent: session.qualityPercent,
        durationMinutes: session.totalInBed.inMinutes,
        totalSessions: db.sessions.length,
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
    if (session != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      );
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                'Spårar din sömn',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _fmt(_elapsed),
                style: TextStyle(
                  fontSize: 56,
                  fontFamily: '.SF Pro Rounded',
                  fontWeight: FontWeight.w300,
                  color: scheme.primary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              const _MovementMeter(),
              const SizedBox(height: 16),
              const _AudioMeter(),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Lägg telefonen med skärmen nedåt på madrassen — '
                  'mikrofonen lyssnar efter ljud, sensorerna mäter rörelse.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Avsluta och spara'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementMeter extends StatelessWidget {
  const _MovementMeter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: SleepTrackingService.instance.currentMovement,
      builder: (_, value, child) {
        return _MeterBar(
          label: 'Rörelse',
          icon: Icons.directions_walk,
          value: value,
          color: scheme.primary,
        );
      },
    );
  }
}

class _AudioMeter extends StatelessWidget {
  const _AudioMeter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<MicPermissionState>(
      valueListenable: AudioRecordingService.instance.permissionState,
      builder: (_, permState, __) {
        if (permState == MicPermissionState.denied ||
            permState == MicPermissionState.permanentlyDenied) {
          return _MicBlockedBanner(
            permanently: permState == MicPermissionState.permanentlyDenied,
          );
        }
        return ValueListenableBuilder<double>(
          valueListenable: AudioRecordingService.instance.currentDb,
          builder: (_, db, ___) {
            // Map -50..-10 dBFS → 0..1 — that's the audibly useful range.
            // Quiet room ≈ -45, normal speech ≈ -25, loud ≈ -15.
            final norm = ((db + 50) / 40).clamp(0.0, 1.0);
            return _MeterBar(
              label: 'Ljud (${db.toStringAsFixed(0)} dB)',
              icon: Icons.mic_rounded,
              value: norm,
              color: scheme.tertiary,
            );
          },
        );
      },
    );
  }
}

class _MicBlockedBanner extends StatelessWidget {
  final bool permanently;
  const _MicBlockedBanner({required this.permanently});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_off_rounded, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                permanently
                    ? 'Mikrofonen är blockerad. Slå på den i Inställningar för '
                        'att registrera snarkningar och ljud.'
                    : 'Mikrofontillstånd saknas — godkänn för att spåra ljud.',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () =>
                  AudioRecordingService.instance.openMicSettings(),
              child: Text(
                permanently ? 'Öppna' : 'Tillåt',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeterBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final Color color;

  const _MeterBar({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

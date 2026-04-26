import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/facebook_analytics_service.dart';
import '../services/sleep_database_service.dart';
import '../services/sleep_tracking_service.dart';
import '../utils/app_theme.dart';
import '../widgets/ad_banner.dart';
import 'sleep_sounds_screen.dart';
import 'tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _alarmKey = 'alarm_target_minutes';
  static const _alarmEnabledKey = 'alarm_enabled';
  static const _smartWindowKey = 'smart_window_minutes';

  TimeOfDay? _alarmTime;
  bool _alarmEnabled = false;
  int _smartWindowMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadAlarm();
  }

  Future<void> _loadAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final mins = prefs.getInt(_alarmKey);
    final enabled = prefs.getBool(_alarmEnabledKey) ?? false;
    final window = prefs.getInt(_smartWindowKey) ?? 30;
    if (mins != null) {
      _alarmTime = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    }
    setState(() {
      _alarmEnabled = enabled;
      _smartWindowMinutes = window;
    });
  }

  Future<void> _saveAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    if (_alarmTime != null) {
      await prefs.setInt(
          _alarmKey, _alarmTime!.hour * 60 + _alarmTime!.minute);
    }
    await prefs.setBool(_alarmEnabledKey, _alarmEnabled);
    await prefs.setInt(_smartWindowKey, _smartWindowMinutes);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _alarmTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (t == null) return;
    setState(() => _alarmTime = t);
    _saveAlarm();
  }

  DateTime? _resolveAlarmTarget() {
    if (!_alarmEnabled || _alarmTime == null) return null;
    final now = DateTime.now();
    var target =
        DateTime(now.year, now.month, now.day, _alarmTime!.hour, _alarmTime!.minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  Future<void> _start() async {
    final db = context.read<SleepDatabaseService>();
    if (!db.loaded) await db.load();
    final total = db.sessions.length;

    await SleepTrackingService.instance.start(
      smartWakeTarget: _resolveAlarmTarget(),
      smartWindow: Duration(minutes: _smartWindowMinutes),
      smartAlarmEnabled: _alarmEnabled,
    );

    FacebookAnalyticsService.instance
        .logSleepSessionStarted(totalSessions: total);

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TrackingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final timeLabel = _alarmTime == null
        ? 'Inget alarm'
        : _alarmTime!.format(context);

    return Container(
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
            const SizedBox(height: 16),
            _StarsHeader(primary: primary),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _AlarmCard(
                    enabled: _alarmEnabled,
                    timeLabel: timeLabel,
                    smartWindow: _smartWindowMinutes,
                    onToggle: (v) {
                      setState(() => _alarmEnabled = v);
                      _saveAlarm();
                    },
                    onPickTime: _pickTime,
                    onWindowChange: (v) {
                      setState(() => _smartWindowMinutes = v);
                      _saveAlarm();
                    },
                  ),
                  const SizedBox(height: 24),
                  _StartButton(onPressed: _start),
                  const SizedBox(height: 12),
                  Text(
                    _alarmEnabled
                        ? 'Smart väckning i lätt sömn upp till $_smartWindowMinutes min innan $timeLabel'
                        : 'Endast sömnanalys — inget alarm',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SleepSoundsButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SleepSoundsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const AdBannerWidget(),
          ],
        ),
      ),
    );
  }
}

class _SleepSoundsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SleepSoundsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.music_note_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sömnljud',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white60),
          ],
        ),
      ),
    );
  }
}

class _StarsHeader extends StatelessWidget {
  final Color primary;
  const _StarsHeader({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, color: primary, size: 28),
          const SizedBox(width: 10),
          const Text(
            'Sömnkoll',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final bool enabled;
  final String timeLabel;
  final int smartWindow;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  final ValueChanged<int> onWindowChange;

  const _AlarmCard({
    required this.enabled,
    required this.timeLabel,
    required this.smartWindow,
    required this.onToggle,
    required this.onPickTime,
    required this.onWindowChange,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.alarm_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Smart väckarklocka',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onPickTime,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, color: scheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Väck-fönster',
                  style: TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                Text('$smartWindow min',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
            Slider(
              value: smartWindow.toDouble(),
              min: 0,
              max: 45,
              divisions: 9,
              onChanged: (v) => onWindowChange(v.round()),
            ),
          ],
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.45),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Starta',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

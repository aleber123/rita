import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sleep_phase.dart';
import '../models/sleep_session.dart';

/// Writes sleep sessions to Apple Health (and Google Health Connect on
/// Android). Pure helper — UI uses [HealthService.instance].
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  static const String _enabledKey = 'health_sync_enabled';
  static const List<HealthDataType> _writeTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_IN_BED,
  ];

  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    Health().configure();
    _configured = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, v);
  }

  /// Returns true if user granted write permission.
  Future<bool> requestPermissions() async {
    await _configure();
    final perms = List<HealthDataAccess>.filled(
      _writeTypes.length,
      HealthDataAccess.WRITE,
    );
    try {
      final granted =
          await Health().requestAuthorization(_writeTypes, permissions: perms);
      return granted;
    } catch (e) {
      debugPrint('[Health] auth failed: $e');
      return false;
    }
  }

  /// Write a session to Apple Health. Each phase becomes a SLEEP_* sample,
  /// plus a single SLEEP_IN_BED block covering the whole session.
  Future<bool> writeSession(SleepSession session) async {
    if (!await isEnabled()) return false;
    await _configure();
    try {
      final inBed = await Health().writeHealthData(
        value: 0,
        type: HealthDataType.SLEEP_IN_BED,
        startTime: session.bedTime,
        endTime: session.wakeTime,
      );
      if (!inBed) return false;
      for (final p in session.phases) {
        final type = _phaseTypeFor(p.kind);
        await Health().writeHealthData(
          value: 0,
          type: type,
          startTime: p.start,
          endTime: p.end,
        );
      }
      return true;
    } catch (e) {
      debugPrint('[Health] write failed: $e');
      return false;
    }
  }

  HealthDataType _phaseTypeFor(SleepPhaseKind kind) {
    switch (kind) {
      case SleepPhaseKind.awake:
        return HealthDataType.SLEEP_AWAKE;
      case SleepPhaseKind.light:
        return HealthDataType.SLEEP_LIGHT;
      case SleepPhaseKind.deep:
        return HealthDataType.SLEEP_DEEP;
      case SleepPhaseKind.rem:
        return HealthDataType.SLEEP_REM;
    }
  }
}

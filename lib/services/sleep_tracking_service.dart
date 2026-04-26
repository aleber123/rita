import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/sleep_phase.dart';
import '../models/sleep_session.dart';
import 'audio_recording_service.dart';
import 'health_service.dart';
import 'sleep_database_service.dart';
import 'snore_analysis_service.dart';

enum TrackingState { idle, running, finishing }

/// Orchestrates a single night of tracking: accelerometer + audio + phase
/// classification + smart alarm.
class SleepTrackingService extends ChangeNotifier {
  SleepTrackingService._();
  static final SleepTrackingService instance = SleepTrackingService._();

  TrackingState _state = TrackingState.idle;
  TrackingState get state => _state;

  String? _sessionId;
  DateTime? _startedAt;
  DateTime? get startedAt => _startedAt;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _phaseTimer;
  Timer? _alarmTimer;

  /// Movement samples since last phase tick.
  final List<double> _movementWindow = [];
  double _restingBaseline = 0.0;

  /// Raw 30s epochs captured during the night, classified post-hoc at stop()
  /// using percentile thresholds across the whole night — see
  /// [_classifyAllEpochs]. This is what real sleep trackers do; absolute
  /// thresholds collapse the entire night into one phase when the phone
  /// sits still on a stable mattress.
  final List<_RawEpoch> _epochs = [];

  /// Captured phases so far for the current session — built live for the
  /// smart-alarm peek, then fully recomputed in [stop] from [_epochs].
  final List<SleepPhase> _phases = [];
  List<SleepPhase> get phases => List.unmodifiable(_phases);

  /// Latest movement intensity (0..1) for the live UI.
  final ValueNotifier<double> currentMovement = ValueNotifier<double>(0);

  /// Configurable alarm settings.
  DateTime? _smartWakeTarget;
  Duration _smartWindow = const Duration(minutes: 30);
  bool _smartAlarmEnabled = true;
  void Function()? _onAlarmFire;

  /// One phase classification every 30 seconds.
  static const Duration _phaseInterval = Duration(seconds: 30);

  bool get isRunning => _state == TrackingState.running;

  /// Start a tracking session. If [smartWakeTarget] is non-null and
  /// [smartAlarmEnabled], we'll fire [onAlarmFire] up to [smartWindow]
  /// before that time when light sleep is detected, otherwise at the target.
  Future<void> start({
    DateTime? smartWakeTarget,
    Duration smartWindow = const Duration(minutes: 30),
    bool smartAlarmEnabled = true,
    void Function()? onAlarmFire,
  }) async {
    if (_state != TrackingState.idle) return;
    _state = TrackingState.running;
    _sessionId = const Uuid().v4();
    _startedAt = DateTime.now();
    _phases.clear();
    _epochs.clear();
    _movementWindow.clear();
    _restingBaseline = 9.81; // gravity baseline magnitude
    _smartWakeTarget = smartWakeTarget;
    _smartWindow = smartWindow;
    _smartAlarmEnabled = smartAlarmEnabled;
    _onAlarmFire = onAlarmFire;

    await WakelockPlus.enable();
    await AudioRecordingService.instance.start(_sessionId!);

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 250),
    ).listen(_onAccel);

    _phaseTimer = Timer.periodic(_phaseInterval, (_) => _captureEpoch());
    if (smartWakeTarget != null) {
      _alarmTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _maybeFireAlarm(),
      );
    }
    notifyListeners();
  }

  /// Stop tracking and persist the completed session.
  Future<SleepSession?> stop({int? userMoodScore, String? notes}) async {
    if (_state == TrackingState.idle) return null;
    _state = TrackingState.finishing;
    _accelSub?.cancel();
    _phaseTimer?.cancel();
    _alarmTimer?.cancel();
    _accelSub = null;
    _phaseTimer = null;
    _alarmTimer = null;
    // Capture trailing partial window as a final epoch.
    if (_movementWindow.isNotEmpty) _captureEpoch();
    // Now that we have every epoch from the night, classify them all
    // relative to each other — this replaces the live phase list.
    _phases
      ..clear()
      ..addAll(_classifyAllEpochs(_epochs));
    await AudioRecordingService.instance.stop();
    await WakelockPlus.disable();

    final start = _startedAt!;
    final wake = DateTime.now();
    final sessionId = _sessionId!;
    final session = SleepSession(
      id: sessionId,
      bedTime: start,
      wakeTime: wake,
      qualityPercent: _computeQuality(_phases),
      userMoodScore: userMoodScore,
      notes: notes,
      phases: List.of(_phases),
    );
    await SleepDatabaseService().saveSession(session);

    // Re-fetch session with persisted clips, then classify snores.
    final saved = SleepDatabaseService()
        .sessions
        .firstWhere((s) => s.id == session.id, orElse: () => session);
    final classifiedClips = await SnoreAnalysisService.classify(saved);
    final finalSession = saved.copyWith(clips: classifiedClips);
    unawaited(HealthService.instance.writeSession(finalSession));

    _sessionId = null;
    _startedAt = null;
    _phases.clear();
    _epochs.clear();
    _state = TrackingState.idle;
    notifyListeners();
    return finalSession;
  }

  void _onAccel(AccelerometerEvent e) {
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final delta = (magnitude - _restingBaseline).abs();
    final intensity = (delta / 4.0).clamp(0.0, 1.0);
    _movementWindow.add(intensity);
    currentMovement.value = intensity;
    // Slowly track baseline (low-pass filter).
    _restingBaseline = _restingBaseline * 0.99 + magnitude * 0.01;
  }

  /// Spike threshold — a single 250ms sample exceeding this counts as a
  /// "movement event" (e.g. a turn, twitch, repositioning). Tuned for a
  /// phone resting on a mattress: gentle rolls register, breathing doesn't.
  static const double _spikeThreshold = 0.08;

  void _captureEpoch() {
    if (_movementWindow.isEmpty || _sessionId == null) return;
    final samples = List<double>.of(_movementWindow);
    _movementWindow.clear();
    final avg = samples.reduce((a, b) => a + b) / samples.length;
    final maxV = samples.reduce(math.max);
    var spikes = 0;
    for (final s in samples) {
      if (s > _spikeThreshold) spikes++;
    }
    final now = DateTime.now();
    _epochs.add(_RawEpoch(
      start: now.subtract(_phaseInterval),
      end: now,
      avg: avg,
      max: maxV,
      spikeCount: spikes,
    ));
    // Provide a coarse live phase guess so the smart alarm has something
    // to peek at — full percentile classification happens at stop().
    final liveKind = _liveGuess(maxV: maxV, spikes: spikes);
    if (_phases.isNotEmpty && _phases.last.kind == liveKind) {
      final last = _phases.removeLast();
      _phases.add(SleepPhase(
        id: last.id,
        sessionId: last.sessionId,
        start: last.start,
        end: now,
        kind: liveKind,
        movement: (last.movement + avg) / 2,
      ));
    } else {
      _phases.add(SleepPhase(
        id: const Uuid().v4(),
        sessionId: _sessionId!,
        start: now.subtract(_phaseInterval),
        end: now,
        kind: liveKind,
        movement: avg,
      ));
    }
    notifyListeners();
  }

  /// Coarse heuristic used only for the smart-alarm window — final phase
  /// list is rebuilt in [_classifyAllEpochs].
  SleepPhaseKind _liveGuess({required double maxV, required int spikes}) {
    if (spikes >= 12 || maxV > 0.6) return SleepPhaseKind.awake;
    if (spikes >= 6) return SleepPhaseKind.light;
    if (spikes >= 2) return SleepPhaseKind.rem;
    return SleepPhaseKind.deep;
  }

  /// Classify every epoch relative to the night's own activity distribution.
  /// Awake epochs (clear motion) are pulled out first; the remainder is
  /// percentile-bucketed so we always get a natural mix of deep/light/REM
  /// regardless of how still the user was overall.
  List<SleepPhase> _classifyAllEpochs(List<_RawEpoch> epochs) {
    if (epochs.isEmpty) return [];
    final sessionId = _sessionId ?? '';

    // Step 1: pull out unambiguously awake epochs — sustained or extreme motion.
    final kinds = List<SleepPhaseKind?>.filled(epochs.length, null);
    for (var i = 0; i < epochs.length; i++) {
      final e = epochs[i];
      if (e.spikeCount >= 12 || e.max > 0.7) {
        kinds[i] = SleepPhaseKind.awake;
      }
    }

    // Step 2: rank remaining epochs by spike count (then avg as tiebreaker)
    // and bucket into deep / light / REM by percentile. Targets a healthy
    // distribution (~25% deep, ~50% light, ~25% REM) which roughly matches
    // adult sleep architecture.
    final remaining = <int>[];
    for (var i = 0; i < epochs.length; i++) {
      if (kinds[i] == null) remaining.add(i);
    }
    remaining.sort((a, b) {
      final s = epochs[a].spikeCount.compareTo(epochs[b].spikeCount);
      if (s != 0) return s;
      return epochs[a].avg.compareTo(epochs[b].avg);
    });
    final deepCutoff = (remaining.length * 0.25).round();
    final lightCutoff = (remaining.length * 0.75).round();
    for (var i = 0; i < remaining.length; i++) {
      final idx = remaining[i];
      if (i < deepCutoff) {
        kinds[idx] = SleepPhaseKind.deep;
      } else if (i < lightCutoff) {
        kinds[idx] = SleepPhaseKind.light;
      } else {
        kinds[idx] = SleepPhaseKind.rem;
      }
    }

    // Step 3: smooth — isolated single-epoch flips between non-awake kinds
    // are mostly noise. Replace any single epoch sandwiched by the same
    // neighbouring kind.
    for (var i = 1; i < kinds.length - 1; i++) {
      final prev = kinds[i - 1];
      final next = kinds[i + 1];
      if (prev == next && prev != SleepPhaseKind.awake && kinds[i] != prev) {
        kinds[i] = prev;
      }
    }

    // Step 4: merge adjacent same-kind epochs into phases.
    final phases = <SleepPhase>[];
    var runStart = epochs.first.start;
    var runKind = kinds.first!;
    var runMovement = epochs.first.avg;
    var runCount = 1;
    for (var i = 1; i < epochs.length; i++) {
      final k = kinds[i]!;
      if (k == runKind) {
        runMovement += epochs[i].avg;
        runCount++;
        continue;
      }
      phases.add(SleepPhase(
        id: const Uuid().v4(),
        sessionId: sessionId,
        start: runStart,
        end: epochs[i].start,
        kind: runKind,
        movement: runMovement / runCount,
      ));
      runStart = epochs[i].start;
      runKind = k;
      runMovement = epochs[i].avg;
      runCount = 1;
    }
    phases.add(SleepPhase(
      id: const Uuid().v4(),
      sessionId: sessionId,
      start: runStart,
      end: epochs.last.end,
      kind: runKind,
      movement: runMovement / runCount,
    ));
    return phases;
  }

  void _maybeFireAlarm() {
    final target = _smartWakeTarget;
    if (target == null) return;
    final now = DateTime.now();
    if (now.isAfter(target)) {
      _fireAlarm();
      return;
    }
    if (!_smartAlarmEnabled) return;
    if (target.difference(now) > _smartWindow) return;
    if (_phases.isEmpty) return;
    final last = _phases.last;
    if (last.kind == SleepPhaseKind.light || last.kind == SleepPhaseKind.rem) {
      _fireAlarm();
    }
  }

  void _fireAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    debugPrint('[Sleep] Alarm fired at ${DateTime.now()}');
    _onAlarmFire?.call();
  }

  int _computeQuality(List<SleepPhase> phases) {
    if (phases.isEmpty) return 0;
    var awake = 0;
    var deep = 0;
    var rem = 0;
    var light = 0;
    for (final p in phases) {
      final s = p.duration.inSeconds;
      switch (p.kind) {
        case SleepPhaseKind.awake:
          awake += s;
          break;
        case SleepPhaseKind.deep:
          deep += s;
          break;
        case SleepPhaseKind.rem:
          rem += s;
          break;
        case SleepPhaseKind.light:
          light += s;
          break;
      }
    }
    final total = awake + deep + rem + light;
    if (total == 0) return 0;
    final asleep = total - awake;
    final asleepPct = asleep / total;
    final deepBonus = (deep / total) * 0.4;
    final remBonus = (rem / total) * 0.3;
    final score = (asleepPct * 0.5 + deepBonus + remBonus + (light / total) * 0.2)
        .clamp(0.0, 1.0);
    return (score * 100).round();
  }
}

class _RawEpoch {
  final DateTime start;
  final DateTime end;
  final double avg;
  final double max;
  final int spikeCount;

  _RawEpoch({
    required this.start,
    required this.end,
    required this.avg,
    required this.max,
    required this.spikeCount,
  });
}

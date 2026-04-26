import 'sleep_phase.dart';
import 'audio_clip.dart';

/// One night of recorded sleep, from "Starta" until alarm/stop.
class SleepSession {
  final String id;
  final DateTime bedTime;
  final DateTime wakeTime;
  final int qualityPercent;
  final int? userMoodScore;
  final String? notes;
  final List<SleepPhase> phases;
  final List<AudioClip> clips;

  SleepSession({
    required this.id,
    required this.bedTime,
    required this.wakeTime,
    required this.qualityPercent,
    this.userMoodScore,
    this.notes,
    this.phases = const [],
    this.clips = const [],
  });

  Duration get totalInBed => wakeTime.difference(bedTime);

  Duration get totalAsleep {
    if (phases.isEmpty) return totalInBed;
    var asleep = Duration.zero;
    for (final p in phases) {
      if (p.kind != SleepPhaseKind.awake) {
        asleep += p.duration;
      }
    }
    return asleep;
  }

  Duration durationOf(SleepPhaseKind kind) {
    var d = Duration.zero;
    for (final p in phases) {
      if (p.kind == kind) d += p.duration;
    }
    return d;
  }

  /// Number of audio clips classified as snoring.
  int get snoreCount => clips.where((c) => c.kind == AudioClipKind.snore).length;

  /// Total seconds of clips classified as snoring.
  int get snoreSeconds {
    var ms = 0;
    for (final c in clips) {
      if (c.kind == AudioClipKind.snore) ms += c.durationMs;
    }
    return ms ~/ 1000;
  }

  /// Loudest snore peak in dBFS (close to 0 = louder).
  double get loudestSnoreDb {
    double peak = -120;
    for (final c in clips) {
      if (c.kind == AudioClipKind.snore && c.peakDb > peak) peak = c.peakDb;
    }
    return peak;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'bed_time': bedTime.millisecondsSinceEpoch,
        'wake_time': wakeTime.millisecondsSinceEpoch,
        'quality_percent': qualityPercent,
        'user_mood_score': userMoodScore,
        'notes': notes,
      };

  factory SleepSession.fromMap(
    Map<String, Object?> map, {
    List<SleepPhase> phases = const [],
    List<AudioClip> clips = const [],
  }) {
    return SleepSession(
      id: map['id'] as String,
      bedTime: DateTime.fromMillisecondsSinceEpoch(map['bed_time'] as int),
      wakeTime: DateTime.fromMillisecondsSinceEpoch(map['wake_time'] as int),
      qualityPercent: map['quality_percent'] as int,
      userMoodScore: map['user_mood_score'] as int?,
      notes: map['notes'] as String?,
      phases: phases,
      clips: clips,
    );
  }

  SleepSession copyWith({
    int? qualityPercent,
    int? userMoodScore,
    String? notes,
    List<SleepPhase>? phases,
    List<AudioClip>? clips,
  }) {
    return SleepSession(
      id: id,
      bedTime: bedTime,
      wakeTime: wakeTime,
      qualityPercent: qualityPercent ?? this.qualityPercent,
      userMoodScore: userMoodScore ?? this.userMoodScore,
      notes: notes ?? this.notes,
      phases: phases ?? this.phases,
      clips: clips ?? this.clips,
    );
  }
}

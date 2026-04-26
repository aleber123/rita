enum SleepPhaseKind {
  awake,
  light,
  deep,
  rem,
}

extension SleepPhaseKindLabel on SleepPhaseKind {
  String get label {
    switch (this) {
      case SleepPhaseKind.awake:
        return 'Vaken';
      case SleepPhaseKind.light:
        return 'Lätt';
      case SleepPhaseKind.deep:
        return 'Djup';
      case SleepPhaseKind.rem:
        return 'Dröm';
    }
  }

  /// Used for the sleep wave graph height (0..1).
  double get curveValue {
    switch (this) {
      case SleepPhaseKind.awake:
        return 1.0;
      case SleepPhaseKind.rem:
        return 0.7;
      case SleepPhaseKind.light:
        return 0.4;
      case SleepPhaseKind.deep:
        return 0.1;
    }
  }
}

class SleepPhase {
  final String id;
  final String sessionId;
  final DateTime start;
  final DateTime end;
  final SleepPhaseKind kind;

  /// Average movement intensity (0-1).
  final double movement;

  SleepPhase({
    required this.id,
    required this.sessionId,
    required this.start,
    required this.end,
    required this.kind,
    this.movement = 0,
  });

  Duration get duration => end.difference(start);

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'kind': kind.index,
        'movement': movement,
      };

  factory SleepPhase.fromMap(Map<String, Object?> map) => SleepPhase(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(map['end'] as int),
        kind: SleepPhaseKind.values[(map['kind'] as int)
            .clamp(0, SleepPhaseKind.values.length - 1)],
        movement: (map['movement'] as num?)?.toDouble() ?? 0,
      );
}

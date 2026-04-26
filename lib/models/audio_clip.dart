enum AudioClipKind {
  snore,
  speech,
  movement,
  cough,
  other,
}

extension AudioClipKindLabel on AudioClipKind {
  String get label {
    switch (this) {
      case AudioClipKind.snore:
        return 'Snarkning';
      case AudioClipKind.speech:
        return 'Sömntal';
      case AudioClipKind.movement:
        return 'Rörelse';
      case AudioClipKind.cough:
        return 'Hosta';
      case AudioClipKind.other:
        return 'Övrigt';
    }
  }

  String get emoji {
    switch (this) {
      case AudioClipKind.snore:
        return '😴';
      case AudioClipKind.speech:
        return '💬';
      case AudioClipKind.movement:
        return '🛏️';
      case AudioClipKind.cough:
        return '😷';
      case AudioClipKind.other:
        return '🔉';
    }
  }
}

class AudioClip {
  final String id;
  final String sessionId;
  final DateTime recordedAt;
  final int durationMs;
  final String filePath;
  final AudioClipKind kind;
  final double peakDb;
  final bool favorite;

  AudioClip({
    required this.id,
    required this.sessionId,
    required this.recordedAt,
    required this.durationMs,
    required this.filePath,
    this.kind = AudioClipKind.other,
    this.peakDb = 0,
    this.favorite = false,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'recorded_at': recordedAt.millisecondsSinceEpoch,
        'duration_ms': durationMs,
        'file_path': filePath,
        'kind': kind.index,
        'peak_db': peakDb,
        'favorite': favorite ? 1 : 0,
      };

  factory AudioClip.fromMap(Map<String, Object?> map) => AudioClip(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        recordedAt:
            DateTime.fromMillisecondsSinceEpoch(map['recorded_at'] as int),
        durationMs: map['duration_ms'] as int,
        filePath: map['file_path'] as String,
        kind: AudioClipKind.values[
            (map['kind'] as int).clamp(0, AudioClipKind.values.length - 1)],
        peakDb: (map['peak_db'] as num?)?.toDouble() ?? 0,
        favorite: (map['favorite'] as int? ?? 0) == 1,
      );

  AudioClip copyWith({AudioClipKind? kind, bool? favorite}) => AudioClip(
        id: id,
        sessionId: sessionId,
        recordedAt: recordedAt,
        durationMs: durationMs,
        filePath: filePath,
        kind: kind ?? this.kind,
        peakDb: peakDb,
        favorite: favorite ?? this.favorite,
      );
}

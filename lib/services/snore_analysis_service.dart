import 'package:flutter/foundation.dart';

import '../models/audio_clip.dart';
import '../models/sleep_phase.dart';
import '../models/sleep_session.dart';
import 'sleep_database_service.dart';

/// Heuristic classifier for audio clips. Marks clips as snore when:
///   - peakDb is loud (≥ -20 dBFS), AND
///   - clip was recorded during a non-awake phase (light/deep/REM).
///
/// We don't have ML on-device, so this is a rules-based first pass. Users
/// can re-classify manually in session detail (TODO).
class SnoreAnalysisService {
  SnoreAnalysisService._();

  /// Loud-event threshold. flutter_sound dBFS ranges from -120 (silent) to 0
  /// (clipping). Sustained snoring typically peaks above -25 dBFS on a phone
  /// next to the bed; -20 is conservative.
  static const double _snorePeakDb = -20;

  /// Classify all clips on the session in-place and persist updates.
  /// Returns the new list with kinds applied.
  static Future<List<AudioClip>> classify(SleepSession session) async {
    if (session.clips.isEmpty) return session.clips;
    final updated = <AudioClip>[];
    final db = SleepDatabaseService();

    for (final clip in session.clips) {
      final kind = _classify(clip, session.phases);
      if (kind != clip.kind) {
        final next = clip.copyWith(kind: kind);
        try {
          await db.updateClip(next);
        } catch (e) {
          debugPrint('[Snore] updateClip failed: $e');
        }
        updated.add(next);
      } else {
        updated.add(clip);
      }
    }
    return updated;
  }

  static AudioClipKind _classify(AudioClip clip, List<SleepPhase> phases) {
    final phase = _phaseAt(clip.recordedAt, phases);
    final asleep = phase != null && phase != SleepPhaseKind.awake;
    if (clip.peakDb >= _snorePeakDb && asleep) {
      return AudioClipKind.snore;
    }
    if (clip.peakDb >= _snorePeakDb && !asleep) {
      // Loud but awake — probably speech or environmental.
      return AudioClipKind.speech;
    }
    return AudioClipKind.other;
  }

  static SleepPhaseKind? _phaseAt(DateTime t, List<SleepPhase> phases) {
    for (final p in phases) {
      if (!t.isBefore(p.start) && t.isBefore(p.end)) return p.kind;
    }
    return null;
  }
}

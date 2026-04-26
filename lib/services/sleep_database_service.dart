import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/audio_clip.dart';
import '../models/sleep_phase.dart';
import '../models/sleep_session.dart';

class SleepDatabaseService extends ChangeNotifier {
  static final SleepDatabaseService _instance =
      SleepDatabaseService._internal();
  factory SleepDatabaseService() => _instance;
  SleepDatabaseService._internal();

  Database? _db;
  List<SleepSession> _sessions = [];
  bool _loaded = false;

  List<SleepSession> get sessions => List.unmodifiable(_sessions);
  bool get loaded => _loaded;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'somnkoll.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sleep_sessions (
        id TEXT PRIMARY KEY,
        bed_time INTEGER NOT NULL,
        wake_time INTEGER NOT NULL,
        quality_percent INTEGER NOT NULL,
        user_mood_score INTEGER,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sleep_phases (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        start INTEGER NOT NULL,
        end INTEGER NOT NULL,
        kind INTEGER NOT NULL,
        movement REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(session_id) REFERENCES sleep_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audio_clips (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        recorded_at INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        kind INTEGER NOT NULL DEFAULT 4,
        peak_db REAL NOT NULL DEFAULT 0,
        favorite INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(session_id) REFERENCES sleep_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_phases_session ON sleep_phases(session_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clips_session ON audio_clips(session_id)');
  }

  Future<void> load() async {
    final db = await _open();
    final sessionRows = await db.query(
      'sleep_sessions',
      orderBy: 'bed_time DESC',
    );
    final result = <SleepSession>[];
    for (final row in sessionRows) {
      final id = row['id'] as String;
      final phaseRows = await db.query('sleep_phases',
          where: 'session_id = ?', whereArgs: [id], orderBy: 'start ASC');
      final clipRows = await db.query('audio_clips',
          where: 'session_id = ?',
          whereArgs: [id],
          orderBy: 'recorded_at ASC');
      result.add(SleepSession.fromMap(
        row,
        phases: phaseRows.map(SleepPhase.fromMap).toList(),
        clips: clipRows.map(AudioClip.fromMap).toList(),
      ));
    }
    _sessions = result;
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveSession(SleepSession session) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.insert(
        'sleep_sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('sleep_phases',
          where: 'session_id = ?', whereArgs: [session.id]);
      for (final phase in session.phases) {
        await txn.insert('sleep_phases', phase.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Don't replace clips wholesale — they are appended individually.
    });
    final idx = _sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      _sessions[idx] = session;
    } else {
      _sessions.insert(0, session);
      _sessions.sort((a, b) => b.bedTime.compareTo(a.bedTime));
    }
    notifyListeners();
  }

  Future<void> addClip(AudioClip clip) async {
    final db = await _open();
    await db.insert('audio_clips', clip.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    final idx = _sessions.indexWhere((s) => s.id == clip.sessionId);
    if (idx >= 0) {
      final updated = [..._sessions[idx].clips, clip];
      _sessions[idx] = _sessions[idx].copyWith(clips: updated);
      notifyListeners();
    }
  }

  Future<void> updateClip(AudioClip clip) async {
    final db = await _open();
    await db.update('audio_clips', clip.toMap(),
        where: 'id = ?', whereArgs: [clip.id]);
    final idx = _sessions.indexWhere((s) => s.id == clip.sessionId);
    if (idx >= 0) {
      final clips = [..._sessions[idx].clips];
      final ci = clips.indexWhere((c) => c.id == clip.id);
      if (ci >= 0) {
        clips[ci] = clip;
        _sessions[idx] = _sessions[idx].copyWith(clips: clips);
        notifyListeners();
      }
    }
  }

  Future<void> deleteSession(String id) async {
    final db = await _open();
    await db.delete('sleep_sessions', where: 'id = ?', whereArgs: [id]);
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Sessions with at least one phase, ordered newest first.
  List<SleepSession> get tracked => _sessions;

  SleepSession? sessionForDate(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    for (final s in _sessions) {
      // Bedtime might be on the previous day, anchor by wake time.
      if (s.wakeTime.isAfter(start) && s.wakeTime.isBefore(end)) {
        return s;
      }
    }
    return null;
  }

  /// Last N sessions newest first.
  List<SleepSession> recent({int limit = 7}) =>
      _sessions.take(limit).toList();

  /// All clips marked favorite, newest first.
  List<AudioClip> favoriteClips() {
    final list = <AudioClip>[];
    for (final s in _sessions) {
      for (final c in s.clips) {
        if (c.favorite) list.add(c);
      }
    }
    list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return list;
  }

  // ── Aggregates used by the Profile/Statistik screens ──────────

  int get totalNights => _sessions.length;

  int get averageQualityPercent {
    if (_sessions.isEmpty) return 0;
    final sum = _sessions.fold<int>(0, (a, s) => a + s.qualityPercent);
    return (sum / _sessions.length).round();
  }

  Duration get averageInBed {
    if (_sessions.isEmpty) return Duration.zero;
    final sum = _sessions.fold<int>(0, (a, s) => a + s.totalInBed.inMinutes);
    return Duration(minutes: (sum / _sessions.length).round());
  }
}

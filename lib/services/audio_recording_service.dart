import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_clip.dart';
import 'sleep_database_service.dart';

/// Records short audio clips when noise crosses a threshold during a
/// sleep tracking session. Clips are stored on disk, metadata in SQLite.
class AudioRecordingService extends ChangeNotifier {
  AudioRecordingService._();
  static final AudioRecordingService instance = AudioRecordingService._();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamSubscription<RecordingDisposition>? _meterSub;
  Timer? _clipTimer;

  String? _activeSessionId;
  bool _opened = false;
  bool _recordingClip = false;
  bool _monitoring = false;
  DateTime? _clipStart;
  String? _clipPath;
  double _peakDbCurrent = -160;
  DateTime? _lastClipAt;

  /// Latest dBFS reading from the mic during monitoring. Range -160
  /// (silence) to 0 (peak); typical room ≈ -45, normal speech ≈ -25.
  final ValueNotifier<double> currentDb = ValueNotifier<double>(-160);

  /// Microphone permission state — surfaced to the UI so users can see
  /// when iOS has silently blocked recording.
  final ValueNotifier<MicPermissionState> permissionState =
      ValueNotifier<MicPermissionState>(MicPermissionState.unknown);

  bool get isMonitoring => _monitoring;

  /// Threshold (dB) for triggering a clip — clips when reading exceeds this.
  /// Lower numbers = more sensitive. flutter_sound dBFS-like values are
  /// typically around -50…0; we treat -25 as "loud event".
  static const double _triggerDb = -25;
  static const Duration _clipDuration = Duration(seconds: 15);
  static const Duration _clipCooldown = Duration(minutes: 2);

  Future<bool> _ensurePermission() async {
    final current = await Permission.microphone.status;
    if (current.isGranted) {
      permissionState.value = MicPermissionState.granted;
      return true;
    }
    if (current.isPermanentlyDenied || current.isRestricted) {
      permissionState.value = MicPermissionState.permanentlyDenied;
      debugPrint('[Audio] Mic permission permanently denied — '
          'user must enable in Settings');
      return false;
    }
    final result = await Permission.microphone.request();
    if (result.isGranted) {
      permissionState.value = MicPermissionState.granted;
      return true;
    }
    permissionState.value = result.isPermanentlyDenied
        ? MicPermissionState.permanentlyDenied
        : MicPermissionState.denied;
    debugPrint('[Audio] Mic permission denied (state=${permissionState.value})');
    return false;
  }

  /// Opens iOS Settings so the user can flip the mic toggle back on.
  Future<void> openMicSettings() async {
    await openAppSettings();
  }

  /// Re-checks permission state without forcing a request prompt — call this
  /// when the user returns from Settings so the UI can update.
  Future<void> refreshPermissionState() async {
    final current = await Permission.microphone.status;
    if (current.isGranted) {
      permissionState.value = MicPermissionState.granted;
    } else if (current.isPermanentlyDenied || current.isRestricted) {
      permissionState.value = MicPermissionState.permanentlyDenied;
    } else if (current.isDenied) {
      permissionState.value = MicPermissionState.denied;
    } else {
      permissionState.value = MicPermissionState.unknown;
    }
  }

  Future<void> start(String sessionId) async {
    if (_monitoring) return;
    final ok = await _ensurePermission();
    if (!ok) {
      debugPrint('[Audio] Mic permission denied — skipping audio monitoring');
      return;
    }
    if (!_opened) {
      await _recorder.openRecorder();
      _opened = true;
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.measurement,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      ));
      await session.setActive(true);
    } catch (e) {
      debugPrint('[Audio] AudioSession configure failed: $e');
    }
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 250));
    _activeSessionId = sessionId;
    _monitoring = true;
    _lastClipAt = null;
    _peakDbCurrent = -160;
    await _startMeteringPass();
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_monitoring) return;
    _monitoring = false;
    _clipTimer?.cancel();
    await _meterSub?.cancel();
    _meterSub = null;
    if (_recordingClip) {
      await _finishClip(saveToDisk: true);
    } else if (_recorder.isRecording) {
      await _recorder.stopRecorder();
    }
    _activeSessionId = null;
    notifyListeners();
  }

  /// Forces a manual snippet to be captured right now.
  Future<void> captureNow() async {
    if (!_monitoring || _recordingClip) return;
    await _beginClip(forced: true);
  }

  Future<String> _newClipPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final clips = Directory(p.join(dir.path, 'audio_clips'));
    if (!clips.existsSync()) clips.createSync(recursive: true);
    final fname = '${DateTime.now().millisecondsSinceEpoch}.aac';
    return p.join(clips.path, fname);
  }

  Future<void> _startMeteringPass() async {
    // Record to a throwaway temp file just so onProgress gives us dB readings.
    final dir = await getTemporaryDirectory();
    final tmp = p.join(dir.path, 'somnkoll_meter.aac');
    if (File(tmp).existsSync()) File(tmp).deleteSync();
    await _recorder.startRecorder(
      toFile: tmp,
      codec: Codec.aacADTS,
      sampleRate: 16000,
      numChannels: 1,
    );
    int tickCount = 0;
    _meterSub = _recorder.onProgress!.listen((event) {
      tickCount++;
      final raw = event.decibels;
      final dbfs = _toDbfs(raw);
      currentDb.value = dbfs;
      if (dbfs > _peakDbCurrent) _peakDbCurrent = dbfs;
      _maybeTriggerClip(dbfs);
      if (tickCount <= 4 || tickCount % 40 == 0) {
        debugPrint('[Audio] meter tick=$tickCount raw=$raw dbfs=$dbfs '
            'recording=${_recorder.isRecording}');
      }
    });
    debugPrint('[Audio] Metering pass started, recorder.isRecording='
        '${_recorder.isRecording}');
  }

  /// Converts flutter_sound's "decibels" value back to standard dBFS.
  /// flutter_sound iOS does `pow(10, peakPower/20) * 160` server-side
  /// (see FlautoRecorderEngine.mm), so we invert that here. Range is
  /// -160 (silence) to 0 (peak).
  static double _toDbfs(double? raw) {
    if (raw == null || raw <= 0.0001) return -160;
    final dbfs = 20 * (math.log(raw / 160.0) / math.ln10);
    if (dbfs.isNaN || dbfs.isInfinite) return -160;
    return dbfs.clamp(-160.0, 0.0);
  }

  void _maybeTriggerClip(double db) {
    if (_recordingClip) return;
    if (db < _triggerDb) return;
    final last = _lastClipAt;
    if (last != null && DateTime.now().difference(last) < _clipCooldown) {
      return;
    }
    unawaited(_beginClip());
  }

  Future<void> _beginClip({bool forced = false}) async {
    if (_recordingClip || _activeSessionId == null) return;
    _recordingClip = true;
    await _meterSub?.cancel();
    _meterSub = null;
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
    }
    final path = await _newClipPath();
    _clipPath = path;
    _clipStart = DateTime.now();
    _peakDbCurrent = -160;
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
      sampleRate: 22050,
      numChannels: 1,
    );
    _meterSub = _recorder.onProgress!.listen((event) {
      final dbfs = _toDbfs(event.decibels);
      currentDb.value = dbfs;
      if (dbfs > _peakDbCurrent) _peakDbCurrent = dbfs;
    });
    _clipTimer = Timer(_clipDuration, () => _finishClip(saveToDisk: true));
    debugPrint('[Audio] Capture clip${forced ? ' (forced)' : ''}: $path');
  }

  Future<void> _finishClip({required bool saveToDisk}) async {
    _clipTimer?.cancel();
    _clipTimer = null;
    final path = _clipPath;
    final start = _clipStart;
    final sessionId = _activeSessionId;
    _clipPath = null;
    _clipStart = null;
    _recordingClip = false;
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
    }
    await _meterSub?.cancel();
    _meterSub = null;
    if (path != null && start != null && sessionId != null) {
      final file = File(path);
      if (file.existsSync() && saveToDisk) {
        final clip = AudioClip(
          id: const Uuid().v4(),
          sessionId: sessionId,
          recordedAt: start,
          durationMs: _clipDuration.inMilliseconds,
          filePath: path,
          kind: AudioClipKind.other,
          peakDb: _peakDbCurrent,
        );
        await SleepDatabaseService().addClip(clip);
        _lastClipAt = DateTime.now();
        debugPrint('[Audio] Saved clip ${clip.id} peak=${clip.peakDb}');
      } else if (file.existsSync()) {
        await file.delete();
      }
    }
    if (_monitoring) {
      await _startMeteringPass();
    }
  }

  Future<void> dispose_() async {
    await stop();
    if (_opened) {
      await _recorder.closeRecorder();
      _opened = false;
    }
  }
}

/// User-facing state of the mic permission. iOS only shows the system
/// prompt once — after that we're stuck in [permanentlyDenied] until the
/// user toggles the setting manually.
enum MicPermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
}

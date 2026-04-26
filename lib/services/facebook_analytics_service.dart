import 'dart:async';
import 'dart:io';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';

/// Wraps Facebook App Events (Conversions API) for Meta ad attribution.
///
/// Usage:
///   await FacebookAnalyticsService.instance.init();
///   FacebookAnalyticsService.instance.logPurchase(amount: 49.0, currency: 'SEK');
class FacebookAnalyticsService {
  FacebookAnalyticsService._();
  static final FacebookAnalyticsService instance = FacebookAnalyticsService._();

  final _fb = FacebookAppEvents();
  bool _initialized = false;

  /// Call once at app startup (after ATT dialog).
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _fb.setAutoLogAppEventsEnabled(true);
      await _fb.setAdvertiserTracking(enabled: true);
      _initialized = true;
      debugPrint('[FB] Analytics initialized');
    } catch (e) {
      debugPrint('[FB] Init error: $e');
    }
  }

  /// Disable tracking (call if user opts out or ATT denied).
  Future<void> disable() async {
    try {
      await _fb.setAutoLogAppEventsEnabled(false);
      await _fb.setAdvertiserTracking(enabled: false);
    } catch (e) {
      debugPrint('[FB] Disable error: $e');
    }
  }

  // ── Standard Meta events ──────────────────────────────────

  /// Fired when a subscription/purchase completes.
  Future<void> logPurchase({
    required double amount,
    String currency = 'SEK',
    Map<String, dynamic>? parameters,
  }) async {
    if (!_initialized) return;
    try {
      await _fb.logPurchase(amount: amount, currency: currency, parameters: parameters);
      debugPrint('[FB] Purchase: $amount $currency');
    } catch (e) {
      debugPrint('[FB] logPurchase error: $e');
    }
  }

  /// Fired when the paywall is shown (InitiateCheckout).
  Future<void> logInitiateCheckout({String? planName}) async {
    if (!_initialized) return;
    try {
      await _fb.logInitiatedCheckout();
      debugPrint('[FB] InitiateCheckout: $planName');
    } catch (e) {
      debugPrint('[FB] logInitiateCheckout error: $e');
    }
  }

  /// Fired when a free trial starts.
  Future<void> logStartTrial({String? planName}) async {
    if (!_initialized) return;
    try {
      await _fb.logEvent(
        name: 'StartTrial',
        parameters: planName != null ? {'plan': planName} : null,
      );
      debugPrint('[FB] StartTrial: $planName');
    } catch (e) {
      debugPrint('[FB] logStartTrial error: $e');
    }
  }

  /// Fired when user completes onboarding / adds first child.
  Future<void> logCompleteRegistration() async {
    if (!_initialized) return;
    try {
      await _fb.logCompletedRegistration(registrationMethod: 'app');
      debugPrint('[FB] CompleteRegistration');
    } catch (e) {
      debugPrint('[FB] logCompleteRegistration error: $e');
    }
  }

  /// Fired when user views a detail screen (entry, child, etc).
  Future<void> logViewContent({required String contentType, String? contentId}) async {
    if (!_initialized) return;
    try {
      await _fb.logViewContent(
        id: contentId,
        type: contentType,
        currency: null,
        price: null,
      );
      debugPrint('[FB] ViewContent: $contentType');
    } catch (e) {
      debugPrint('[FB] logViewContent error: $e');
    }
  }

  /// Fired when user dismisses the paywall without purchasing.
  Future<void> logPaywallDismiss({String? source}) async {
    if (!_initialized) return;
    try {
      await _fb.logEvent(
        name: 'PaywallDismiss',
        parameters: source != null ? {'source': source} : null,
      );
      debugPrint('[FB] PaywallDismiss: $source');
    } catch (e) {
      debugPrint('[FB] logPaywallDismiss error: $e');
    }
  }

  // ── Sömn-specific events ──────────────────────────────────

  /// Fired when user starts a sleep session (Starta).
  Future<void> logSleepSessionStarted({int totalSessions = 0}) async {
    if (!_initialized) return;
    try {
      if (totalSessions == 0) {
        await _fb.logCompletedRegistration(
            registrationMethod: 'first_sleep_session');
      }
      await _fb.logEvent(
        name: 'SleepSessionStarted',
        parameters: {'total': totalSessions},
      );
      debugPrint('[FB] SleepSessionStarted (total=$totalSessions)');
    } catch (e) {
      debugPrint('[FB] logSleepSessionStarted error: $e');
    }
  }

  /// Fired when a sleep session is saved to the journal.
  Future<void> logSleepSessionSaved({
    required int qualityPercent,
    required int durationMinutes,
    int totalSessions = 0,
  }) async {
    if (!_initialized) return;
    try {
      await _fb.logEvent(
        name: 'SleepSessionSaved',
        parameters: {
          'quality': qualityPercent,
          'duration_min': durationMinutes,
          'total': totalSessions,
        },
      );
      debugPrint(
          '[FB] SleepSessionSaved (quality=$qualityPercent, total=$totalSessions)');
    } catch (e) {
      debugPrint('[FB] logSleepSessionSaved error: $e');
    }
  }

  /// Fired when user listens to one of their recorded audio clips.
  Future<void> logAudioClipPlayed({String? kind}) async {
    if (!_initialized) return;
    try {
      await _fb.logEvent(
        name: 'AudioClipPlayed',
        parameters: kind != null ? {'kind': kind} : null,
      );
    } catch (e) {
      debugPrint('[FB] logAudioClipPlayed error: $e');
    }
  }

  /// Fired when user enables the smart alarm.
  Future<void> logSmartAlarmSet() async {
    if (!_initialized) return;
    try {
      await _fb.logEvent(name: 'SmartAlarmSet');
    } catch (e) {
      debugPrint('[FB] logSmartAlarmSet error: $e');
    }
  }
}

/// Handles iOS App Tracking Transparency dialog and initializes FB accordingly.
class AttPermissionHandler {
  /// Call this once from main.dart after the first frame.
  static Future<void> requestAndInit() async {
    if (!Platform.isIOS) {
      await FacebookAnalyticsService.instance.init();
      return;
    }

    try {
      // iPadOS 26+ silently no-ops requestTrackingAuthorization if the app
      // isn't fully foregrounded. Wait until the lifecycle reports resumed
      // before showing the prompt.
      await _waitUntilResumed();

      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      debugPrint('[ATT] Initial status: $status');

      if (status == TrackingStatus.notDetermined) {
        // Even when resumed, the system can return notDetermined on the first
        // call right after launch. Retry with backoff before giving up.
        for (var attempt = 0; attempt < 4; attempt++) {
          final delay = Duration(milliseconds: 600 + attempt * 600);
          await Future.delayed(delay);
          await _waitUntilResumed();
          final result =
              await AppTrackingTransparency.requestTrackingAuthorization();
          debugPrint('[ATT] Request result (attempt $attempt): $result');
          if (result != TrackingStatus.notDetermined) {
            status = result;
            break;
          }
        }
      }

      if (status == TrackingStatus.authorized) {
        await FacebookAnalyticsService.instance.init();
      } else {
        await FacebookAnalyticsService.instance.disable();
      }
    } catch (e) {
      debugPrint('[ATT] Error: $e');
      // Only enable FB on non-iOS error paths; iOS errors must NOT bypass ATT.
      await FacebookAnalyticsService.instance.disable();
    }
  }

  /// Waits until WidgetsBinding reports AppLifecycleState.resumed.
  /// Returns immediately if already resumed; bails out after 5s as a safety net.
  static Future<void> _waitUntilResumed() async {
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == AppLifecycleState.resumed) return;

    final completer = Completer<void>();
    late final _LifecycleWatcher watcher;
    watcher = _LifecycleWatcher(() {
      if (!completer.isCompleted) completer.complete();
    });
    binding.addObserver(watcher);

    try {
      await completer.future.timeout(const Duration(seconds: 5),
          onTimeout: () {});
    } finally {
      binding.removeObserver(watcher);
    }
  }
}

class _LifecycleWatcher with WidgetsBindingObserver {
  final VoidCallback onResumed;
  _LifecycleWatcher(this.onResumed);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

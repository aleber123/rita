import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // AdMob App IDs — Sömnkoll iOS app
  // TODO: replace with Sömnkoll-specific AdMob unit IDs once created.
  // Empty production IDs fall back to Google test units (see getBannerAdUnitId).
  static const String appIdAndroid = '';
  static const String appIdIos = 'ca-app-pub-4013461464810205~8344810321';

  // Production banner ad unit IDs
  static const String bannerAdUnitIdAndroid = '';
  static const String bannerAdUnitIdIos = 'ca-app-pub-4013461464810205/8205209524';

  // Production interstitial ad unit IDs
  static const String interstitialAdUnitIdAndroid = '';
  static const String interstitialAdUnitIdIos = 'ca-app-pub-4013461464810205/1377656304';

  // Test IDs (use during development)
  static const String testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  // Rewarded ad unit IDs
  static const String rewardedAdUnitIdAndroid = '';
  static const String rewardedAdUnitIdIos = 'ca-app-pub-4013461464810205/4353594427';

  // App Open ad unit IDs
  static const String appOpenAdUnitIdAndroid = '';
  static const String appOpenAdUnitIdIos = 'ca-app-pub-4013461464810205/5316901317';
  static const String testAppOpenAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String testAppOpenIos = 'ca-app-pub-3940256099942544/5575463023';

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  int _interstitialCloseCounter = 0;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;
  bool _isShowingAppOpenAd = false;
  DateTime? _appOpenAdLoadTime;

  /// Initializes the AdMob SDK.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    await _requestConsentInfo();
    await MobileAds.instance.initialize();
    _isInitialized = true;
    loadAppOpenAd();
    loadRewardedAd();
    loadInterstitial();
  }

  /// Requests consent info from Google UMP servers.
  /// Safe to call before runApp() — only performs a network request.
  Future<void> _requestConsentInfo() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => completer.complete(),
      (FormError error) {
        debugPrint('[AdService] Consent info request failed: ${error.message}');
        completer.complete();
      },
    );
    return completer.future;
  }

  /// Shows the GDPR consent form if required (for EU/EEA users).
  /// MUST be called from a widget with a valid UI context (after runApp).
  /// Call this before loading any ads to ensure GDPR compliance.
  Future<void> showConsentFormIfNeeded() async {
    if (kIsWeb) return;

    try {
      final isAvailable =
          await ConsentInformation.instance.isConsentFormAvailable();
      if (!isAvailable) return;

      final completer = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) {
          debugPrint('[AdService] Consent form error: ${error.message}');
        }
        completer.complete();
      });
      await completer.future;
    } catch (e) {
      debugPrint('[AdService] showConsentFormIfNeeded error: $e');
    }
  }

  /// Returns the correct banner ad unit ID for the current build mode and platform.
  /// Falls back to test IDs if the production ID is empty (still pending in AdMob).
  static String getBannerAdUnitId() {
    const bool isRelease = bool.fromEnvironment('dart.vm.product');
    final isIos = !kIsWeb && Platform.isIOS;
    if (isRelease) {
      final prod = isIos ? bannerAdUnitIdIos : bannerAdUnitIdAndroid;
      if (prod.isNotEmpty) return prod;
    }
    return isIos ? testBannerIos : testBannerAndroid;
  }

  BannerAd createBannerAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: getBannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  static String getInterstitialAdUnitId() {
    const bool isRelease = bool.fromEnvironment('dart.vm.product');
    final isIos = !kIsWeb && Platform.isIOS;
    if (isRelease) {
      final prod = isIos ? interstitialAdUnitIdIos : interstitialAdUnitIdAndroid;
      if (prod.isNotEmpty) return prod;
    }
    return isIos ? testInterstitialIos : testInterstitialAndroid;
  }

  /// Preload an interstitial ad so it's ready to show.
  Future<void> loadInterstitial() async {
    if (kIsWeb) return;
    if (_interstitialAd != null) return;

    await InterstitialAd.load(
      adUnitId: getInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial failed: ${error.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Shows a preloaded interstitial every Nth call (default: 1 in 2).
  /// Returns true if an ad was shown.
  Future<bool> maybeShowInterstitial({int frequency = 2}) async {
    if (kIsWeb) return false;
    _interstitialCloseCounter++;
    if (_interstitialCloseCounter % frequency != 0) {
      // Preload next one in background so it's ready when needed.
      loadInterstitial();
      return false;
    }
    final ad = _interstitialAd;
    if (ad == null) {
      loadInterstitial();
      return false;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
      },
    );
    await ad.show();
    return true;
  }

  // ── Rewarded Ad ──────────────────────────────────────────────

  static const String testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  static String getRewardedAdUnitId() {
    const bool isRelease = bool.fromEnvironment('dart.vm.product');
    final isIos = !kIsWeb && Platform.isIOS;
    if (isRelease) {
      final prod = isIos ? rewardedAdUnitIdIos : rewardedAdUnitIdAndroid;
      if (prod.isNotEmpty) return prod;
    }
    return isIos ? testRewardedIos : testRewardedAndroid;
  }

  Future<void> loadRewardedAd() async {
    if (kIsWeb) return;
    if (_rewardedAd != null) return;
    await RewardedAd.load(
      adUnitId: getRewardedAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded ad failed: ${error.message}');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Shows a rewarded ad. Returns true if the user watched the full ad.
  Future<bool> showRewardedAd() async {
    if (kIsWeb) return false;
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewardedAd();
      return false;
    }

    final completer = Completer<bool>();
    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        completer.complete(false);
      },
    );

    await ad.show(onUserEarnedReward: (ad, reward) {
      rewarded = true;
    });

    return completer.future;
  }

  bool get isRewardedAdReady => _rewardedAd != null;

  // ── App Open Ad ─────────────────────────────────────────────

  static String getAppOpenAdUnitId() {
    const bool isRelease = bool.fromEnvironment('dart.vm.product');
    final isIos = !kIsWeb && Platform.isIOS;
    if (isRelease) {
      final prod = isIos ? appOpenAdUnitIdIos : appOpenAdUnitIdAndroid;
      if (prod.isNotEmpty) return prod;
    }
    return isIos ? testAppOpenIos : testAppOpenAndroid;
  }

  void loadAppOpenAd() {
    if (kIsWeb) return;
    AppOpenAd.load(
      adUnitId: getAppOpenAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAdLoadTime = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] App open ad failed: ${error.message}');
          _appOpenAd = null;
        },
      ),
    );
  }

  bool get _isAppOpenAdAvailable {
    if (_appOpenAd == null || _appOpenAdLoadTime == null) return false;
    // Google recommends not showing ads older than 4 hours
    return DateTime.now().difference(_appOpenAdLoadTime!).inHours < 4;
  }

  Future<void> showAppOpenAd() async {
    if (kIsWeb) return;
    if (_isShowingAppOpenAd) return;
    if (!_isAppOpenAdAvailable) {
      loadAppOpenAd();
      return;
    }

    _isShowingAppOpenAd = true;
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpenAd = false;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpenAd = false;
        loadAppOpenAd();
      },
    );
    await _appOpenAd!.show();
  }
}

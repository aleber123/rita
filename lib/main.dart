import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'providers/favorites_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/root_shell.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/facebook_analytics_service.dart';
import 'services/notification_service.dart';
import 'services/premium_service.dart';
import 'services/sleep_database_service.dart';
import 'services/theme_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final currentLocale = ui.PlatformDispatcher.instance.locale.toLanguageTag();
  await Future.wait([
    ThemeService().initialize(),
    initializeDateFormatting(currentLocale, null),
  ]);

  runApp(const SomnkollApp());

  _initializeRemainingLocales(currentLocale);
}

void _initializeRemainingLocales(String current) {
  const locales = ['sv', 'en'];
  for (final l in locales) {
    if (!current.startsWith(l)) {
      initializeDateFormatting(l, null);
    }
  }
}

Future<void> _initializeServices() async {
  await PremiumService().initialize();
  await SleepDatabaseService().load();
  await NotificationService.instance.initialize();
}

Future<void> _initializeBackgroundServices() async {
  if (!kIsWeb) {
    await AdService().initialize();
  }
}

class SomnkollApp extends StatelessWidget {
  const SomnkollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesProvider()..load()),
        ChangeNotifierProvider(create: (_) => PremiumService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => SleepDatabaseService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Sömnkoll',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme.copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeService.primaryColor,
                brightness: Brightness.dark,
              ),
            ),
            darkTheme: AppTheme.darkTheme.copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeService.primaryColor,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: ThemeMode.dark,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const _SplashWrapper(),
          );
        },
      ),
    );
  }
}

class _SplashWrapper extends StatefulWidget {
  const _SplashWrapper();

  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper> {
  bool _showHome = false;
  bool _needsOnboarding = false;
  Future<void>? _serviceInit;

  static const String _onboardingDoneKey = 'has_completed_onboarding';
  static const String _onboardingPaywallKey = 'has_seen_onboarding_paywall';
  static const String _appOpenCountKey = 'app_open_count';

  @override
  void initState() {
    super.initState();
    _serviceInit = _initializeServices();
  }

  Future<void> _postLaunchFlow() async {
    final frameDone = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => frameDone.complete());
    await frameDone.future;
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    await AttPermissionHandler.requestAndInit();
    if (!mounted) return;

    _initializeBackgroundServices();
    await AdService().showConsentFormIfNeeded();
    if (!mounted) return;

    final premium = PremiumService();
    if (!premium.isPremium) {
      final prefs = await SharedPreferences.getInstance();
      final openCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
      await prefs.setInt(_appOpenCountKey, openCount);
      final hasSeenOnboarding = prefs.getBool(_onboardingPaywallKey) ?? false;

      final shouldShow = !hasSeenOnboarding || openCount % 3 == 0;
      if (shouldShow) {
        if (!hasSeenOnboarding) {
          await prefs.setBool(_onboardingPaywallKey, true);
        }
        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  PaywallScreen(
                      source: hasSeenOnboarding ? 'periodic' : 'onboarding'),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        AdService().showAppOpenAd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsOnboarding) {
      return OnboardingScreen(
        onDone: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_onboardingDoneKey, true);
          if (!mounted) return;
          setState(() {
            _needsOnboarding = false;
            _showHome = true;
          });
          _postLaunchFlow();
        },
      );
    }

    if (_showHome) return const RootShell();

    return SplashScreen(
      onComplete: () async {
        if (!mounted) return;
        await _serviceInit;
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        final done = prefs.getBool(_onboardingDoneKey) ?? false;
        if (!done) {
          setState(() => _needsOnboarding = true);
          return;
        }
        setState(() => _showHome = true);
        _postLaunchFlow();
      },
    );
  }
}

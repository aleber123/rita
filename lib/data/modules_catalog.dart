import '../models/drawing.dart';
import '../models/module.dart';

/// Hardcoded list of available modules. Drawing PNGs live under
/// `assets/drawings/<module-id>/`. The "free" module ships in the bundle;
/// premium modules ship in the bundle too but are gated by an IAP unlock
/// stored in `ModuleService`.
class ModulesCatalog {
  static const String pkgPrefix = 'com.alexanderbergqvist.ritaapp.module.';
  static const String subPrefix =
      'com.alexanderbergqvist.ritaapp.subscription.';

  /// Auto-renewing subscriptions that unlock every module while active.
  /// Configure in App Store Connect under one Subscription Group.
  static const String subscriptionMonthly = '${subPrefix}monthly';
  static const String subscriptionYearly = '${subPrefix}yearly';

  static const Set<String> subscriptionIds = {
    subscriptionMonthly,
    subscriptionYearly,
  };

  /// One-time IAP that unlocks the "Förvandla ett kort" feature. Also
  /// unlocked automatically while a subscription is active.
  static const String photoProductId = '${pkgPrefix}photo';

  /// One-time IAP that unlocks the premium pens (regnbåge, glitter, neon).
  /// Also unlocked automatically while a subscription is active.
  static const String magicPensProductId = '${pkgPrefix}magic_pens';

  static const List<DrawingModule> all = [
    DrawingModule(
      id: 'free',
      title: 'Smakprov',
      emoji: '🎨',
      drawings: [
        Drawing(
          id: 'free_blank',
          title: 'Tomt blad',
          assetPath: 'assets/drawings/free/blank.png',
        ),
        Drawing(
          id: 'free_unicorn',
          title: 'Enhörning',
          assetPath: 'assets/drawings/free/unicorn.png',
        ),
      ],
    ),
    DrawingModule(
      id: 'unicorns',
      title: 'Enhörningar',
      emoji: '🦄',
      productId: '${pkgPrefix}unicorns',
      drawings: [
        Drawing(id: 'unicorn_1', title: 'Enhörning 1', assetPath: 'assets/drawings/unicorns/unicorn_1.png'),
        Drawing(id: 'unicorn_2', title: 'Enhörning 2', assetPath: 'assets/drawings/unicorns/unicorn_2.png'),
        Drawing(id: 'unicorn_3', title: 'Enhörning 3', assetPath: 'assets/drawings/unicorns/unicorn_3.png'),
        Drawing(id: 'unicorn_4', title: 'Enhörning 4', assetPath: 'assets/drawings/unicorns/unicorn_4.png'),
        Drawing(id: 'unicorn_5', title: 'Enhörning 5', assetPath: 'assets/drawings/unicorns/unicorn_5.png'),
      ],
    ),
    DrawingModule(
      id: 'superheroes',
      title: 'Superhjältar',
      emoji: '🦸',
      productId: '${pkgPrefix}superheroes',
      drawings: [
        Drawing(id: 'hero_1', title: 'Superhjälte 1', assetPath: 'assets/drawings/superheroes/hero_1.png'),
        Drawing(id: 'hero_2', title: 'Superhjälte 2', assetPath: 'assets/drawings/superheroes/hero_2.png'),
        Drawing(id: 'hero_3', title: 'Superhjälte 3', assetPath: 'assets/drawings/superheroes/hero_3.png'),
        Drawing(id: 'hero_4', title: 'Superhjälte 4', assetPath: 'assets/drawings/superheroes/hero_4.png'),
        Drawing(id: 'hero_5', title: 'Superhjälte 5', assetPath: 'assets/drawings/superheroes/hero_5.png'),
        Drawing(id: 'hero_6', title: 'Superhjälte 6', assetPath: 'assets/drawings/superheroes/hero_6.png'),
      ],
    ),
    DrawingModule(
      id: 'animals',
      title: 'Djur',
      emoji: '🐶',
      productId: '${pkgPrefix}animals',
      drawings: [
        Drawing(id: 'animal_1', title: 'Djur 1', assetPath: 'assets/drawings/animals/animal_1.png'),
        Drawing(id: 'animal_2', title: 'Djur 2', assetPath: 'assets/drawings/animals/animal_2.png'),
        Drawing(id: 'animal_3', title: 'Djur 3', assetPath: 'assets/drawings/animals/animal_3.png'),
        Drawing(id: 'animal_4', title: 'Djur 4', assetPath: 'assets/drawings/animals/animal_4.png'),
        Drawing(id: 'animal_5', title: 'Djur 5', assetPath: 'assets/drawings/animals/animal_5.png'),
        Drawing(id: 'animal_6', title: 'Djur 6', assetPath: 'assets/drawings/animals/animal_6.png'),
      ],
    ),
    DrawingModule(
      id: 'vehicles',
      title: 'Fordon',
      emoji: '🚗',
      productId: '${pkgPrefix}vehicles',
      drawings: [
        Drawing(id: 'vehicle_1', title: 'Fordon 1', assetPath: 'assets/drawings/vehicles/vehicle_1.png'),
        Drawing(id: 'vehicle_2', title: 'Fordon 2', assetPath: 'assets/drawings/vehicles/vehicle_2.png'),
        Drawing(id: 'vehicle_3', title: 'Fordon 3', assetPath: 'assets/drawings/vehicles/vehicle_3.png'),
        Drawing(id: 'vehicle_4', title: 'Fordon 4', assetPath: 'assets/drawings/vehicles/vehicle_4.png'),
        Drawing(id: 'vehicle_5', title: 'Fordon 5', assetPath: 'assets/drawings/vehicles/vehicle_5.png'),
        Drawing(id: 'vehicle_6', title: 'Fordon 6', assetPath: 'assets/drawings/vehicles/vehicle_6.png'),
        Drawing(id: 'vehicle_7', title: 'Fordon 7', assetPath: 'assets/drawings/vehicles/vehicle_7.png'),
        Drawing(id: 'vehicle_8', title: 'Fordon 8', assetPath: 'assets/drawings/vehicles/vehicle_8.png'),
      ],
    ),
    DrawingModule(
      id: 'dinosaurs',
      title: 'Dinosaurier',
      emoji: '🦕',
      productId: '${pkgPrefix}dinosaurs',
      drawings: [
        Drawing(id: 'dino_1', title: 'Dinosaurie 1', assetPath: 'assets/drawings/dinosaurs/dino_1.png'),
        Drawing(id: 'dino_2', title: 'Dinosaurie 2', assetPath: 'assets/drawings/dinosaurs/dino_2.png'),
        Drawing(id: 'dino_3', title: 'Dinosaurie 3', assetPath: 'assets/drawings/dinosaurs/dino_3.png'),
        Drawing(id: 'dino_4', title: 'Dinosaurie 4', assetPath: 'assets/drawings/dinosaurs/dino_4.png'),
        Drawing(id: 'dino_5', title: 'Dinosaurie 5', assetPath: 'assets/drawings/dinosaurs/dino_5.png'),
        Drawing(id: 'dino_6', title: 'Dinosaurie 6', assetPath: 'assets/drawings/dinosaurs/dino_6.png'),
        Drawing(id: 'dino_7', title: 'Dinosaurie 7', assetPath: 'assets/drawings/dinosaurs/dino_7.png'),
      ],
    ),
  ];
}

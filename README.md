# VAB-koll

Enkel VAB-app för svenska föräldrar – logga vård av barn, håll koll på 90-dagarsdeadlinen till Försäkringskassan och se uppskattad ersättning. Byggd med Flutter.

VAB-koll är inte associerad med eller godkänd av Försäkringskassan.

## Funktioner

- **Logga VAB-dagar** per barn med datum, andel (12,5/25/50/75/100 %), orsak och anteckningar
- **Flera barn** – separata räknare mot 120-dagarsgränsen per barn/år (Premium)
- **Deadline-påminnelser** – 60/75/85 dagar efter VAB-dagen om du inte anmält till FK
- **Läkarintygspåminnelse** – dag 7 inför dag 8-kravet
- **Ersättningskalkyl** – 77,6 % av SGI med FK:s tak (2026: 591 000 kr)
- **Kalendervy** – månadsöversikt med VAB-dagar markerade
- **CSV-export** – för bokföring eller delning med arbetsgivaren (Premium)
- **100 % lokalt** – all data sparas på enheten, ingen molnsynk

## Teknikstack

| Komponent | Teknologi |
|-----------|-----------|
| Framework | Flutter 3.10+ (Dart ^3.10.8) |
| Databas | SQLite via sqflite |
| State | Provider |
| Notiser | flutter_local_notifications |
| Kalender | table_calendar |
| Annonser | google_mobile_ads |
| Analytics | facebook_app_events (ATT-gated) |
| IAP | in_app_purchase |

## Kom igång

### Förutsättningar
- Flutter SDK 3.10+
- Xcode (för iOS)
- Android Studio (för Android)
- CocoaPods (`brew install cocoapods`)

### Installation

```bash
cd vab_app
flutter pub get
flutter run -d ios
```

### Tester

```bash
flutter test
flutter analyze
```

## Projektstruktur

```
lib/
├── main.dart                        # App-startpunkt
├── models/
│   ├── child.dart                   # Barn (förnamn, födelseår)
│   └── vab_entry.dart               # VAB-post
├── providers/
│   ├── child_provider.dart
│   └── vab_entry_provider.dart
├── screens/
│   ├── home_screen.dart             # Dashboard + per-barn översikt
│   ├── calendar_screen.dart         # TableCalendar med VAB-dagar
│   ├── children_screen.dart         # Lista + CRUD för barn
│   ├── child_form_screen.dart
│   ├── vab_entry_form_screen.dart
│   ├── paywall_screen.dart          # Premium
│   └── settings_screen.dart
├── services/
│   ├── database_service.dart
│   ├── notification_service.dart    # Deadline- & läkarintygspåminnelser
│   ├── export_service.dart          # CSV
│   ├── ad_service.dart              # AdMob
│   ├── facebook_analytics_service.dart
│   └── premium_service.dart         # IAP + gating
└── utils/
    ├── app_theme.dart
    └── constants.dart
```

## Monetisering (Freemium)

**Gratis:**
- 1 barn
- Max 20 VAB-poster
- Banner-annonser

**Premium (månadsvis / årsvis / livstid):**
- Flera barn
- Obegränsade VAB-poster
- Deadline-påminnelser
- Årsrapport per barn
- Ersättningskalkyl
- CSV-export
- Inga annonser

## Licens

Privat projekt – alla rättigheter förbehållna.

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('sv'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('sv'),
    Locale('en'),
  ];

  static final Map<String, Map<String, String>> _translations = {
    'sv': _sv,
    'en': _en,
  };

  String get(String key) {
    return _translations[locale.languageCode]?[key] ??
        _translations['sv']?[key] ??
        key;
  }

  // --- Convenience getters ---
  String get appName => get('app_name');
  String get home => get('home');
  String get calendar => get('calendar');
  String get children => get('children');
  String get settings => get('settings');
  String get addEntry => get('add_entry');
  String get addChild => get('add_child');
  String get editEntry => get('edit_entry');
  String get editChild => get('edit_child');
  String get daysUsed => get('days_used');
  String get daysRemaining => get('days_remaining');
  String get estimatedPayout => get('estimated_payout');
  String get submitToFk => get('submit_to_fk');
  String get markAsSubmitted => get('mark_as_submitted');
  String get deadline => get('deadline');
  String get doctorsNote => get('doctors_note');
  String get share => get('share_fraction');
  String get reason => get('reason');
  String get note => get('note');
  String get date => get('date');
  String get child => get('child');
  String get sgiAnnual => get('sgi_annual');
  String get premium => get('premium');
  String get upgrade => get('upgrade');
  String get cancel => get('cancel');
  String get save => get('save');
  String get delete => get('delete');
  String get exportCsv => get('export_csv');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['sv', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, String> _sv = {
  'app_name': 'VAB-koll',
  'app_tagline': 'Håll koll på VAB-dagar och deadlines',
  'home': 'Hem',
  'calendar': 'Kalender',
  'children': 'Barn',
  'settings': 'Inställningar',
  'add_entry': 'Lägg till VAB-dag',
  'add_child': 'Lägg till barn',
  'edit_entry': 'Ändra VAB-dag',
  'edit_child': 'Ändra barn',
  'days_used': 'Använda dagar',
  'days_remaining': 'Dagar kvar',
  'estimated_payout': 'Uppskattad ersättning',
  'submit_to_fk': 'Anmäl till Försäkringskassan',
  'mark_as_submitted': 'Markera som anmäld',
  'deadline': 'Deadline',
  'doctors_note': 'Läkarintyg',
  'share_fraction': 'Andel',
  'reason': 'Anledning',
  'note': 'Anteckning',
  'date': 'Datum',
  'child': 'Barn',
  'sgi_annual': 'SGI per år',
  'premium': 'Premium',
  'upgrade': 'Uppgradera',
  'cancel': 'Avbryt',
  'save': 'Spara',
  'delete': 'Ta bort',
  'export_csv': 'Exportera CSV',
  'deadline_reminder_title': 'Snart deadline för VAB-anmälan',
  'deadline_reminder_body':
      '{days} dagar kvar att anmäla till Försäkringskassan',
  'doctor_note_reminder_title': 'Dags för läkarintyg',
  'doctor_note_reminder_body':
      'Från dag 8 behöver Försäkringskassan ett läkarintyg',
  'reason_sick': 'Sjuk',
  'reason_doctor_visit': 'Läkarbesök',
  'reason_contagion': 'Smitta',
  'reason_hospital_visit': 'Sjukhusbesök',
  'reason_other': 'Annat',
};

const Map<String, String> _en = {
  'app_name': 'VAB Tracker',
  'app_tagline': 'Track VAB days and FK deadlines',
  'home': 'Home',
  'calendar': 'Calendar',
  'children': 'Children',
  'settings': 'Settings',
  'add_entry': 'Add VAB day',
  'add_child': 'Add child',
  'edit_entry': 'Edit VAB day',
  'edit_child': 'Edit child',
  'days_used': 'Days used',
  'days_remaining': 'Days remaining',
  'estimated_payout': 'Estimated payout',
  'submit_to_fk': 'Submit to Försäkringskassan',
  'mark_as_submitted': 'Mark as submitted',
  'deadline': 'Deadline',
  'doctors_note': "Doctor's note",
  'share_fraction': 'Share',
  'reason': 'Reason',
  'note': 'Note',
  'date': 'Date',
  'child': 'Child',
  'sgi_annual': 'Annual SGI',
  'premium': 'Premium',
  'upgrade': 'Upgrade',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'export_csv': 'Export CSV',
  'deadline_reminder_title': 'VAB submission deadline approaching',
  'deadline_reminder_body': '{days} days left to submit to FK',
  'doctor_note_reminder_title': "Time for a doctor's note",
  'doctor_note_reminder_body':
      "From day 8 Försäkringskassan requires a doctor's note",
  'reason_sick': 'Sick',
  'reason_doctor_visit': 'Doctor visit',
  'reason_contagion': 'Contagion',
  'reason_hospital_visit': 'Hospital visit',
  'reason_other': 'Other',
};

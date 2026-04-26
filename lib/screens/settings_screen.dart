import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import '../services/premium_service.dart';
import '../services/theme_service.dart';
import '../utils/constants.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _amazonTag = 'alexanderbe05-21';

  static const List<_AmazonProduct> _tools = [
    _AmazonProduct(
      emoji: '🛏️',
      name: 'Madrass & madrasskydd',
      query: 'madrass memory foam pocket',
    ),
    _AmazonProduct(
      emoji: '💤',
      name: 'Ergonomisk kudde',
      query: 'ergonomisk kudde minnesmaterial',
    ),
    _AmazonProduct(
      emoji: '🌙',
      name: 'Sömnmask & öronproppar',
      query: 'sömnmask öronproppar resepaket',
    ),
    _AmazonProduct(
      emoji: '🌿',
      name: 'Lavendel & aromaterapi',
      query: 'lavendel essential oil sömn',
    ),
    _AmazonProduct(
      emoji: '🎵',
      name: 'Vitt brus / sömnmaskin',
      query: 'white noise machine sömn',
    ),
    _AmazonProduct(
      emoji: '🍵',
      name: 'Sömnte & magnesium',
      query: 'sömnte magnesium melatonin',
    ),
  ];

  String _amazonUrl(String query) {
    final q = Uri.encodeComponent(query);
    return 'https://www.amazon.se/s?k=$q&tag=$_amazonTag';
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Inställningar')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: Text(premium.isPremium ? 'Premium' : 'Uppgradera'),
              subtitle: Text(premium.isPremium
                  ? 'Aktivt abonnemang'
                  : 'Lås upp alla verktyg och funktioner'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PaywallScreen(source: 'settings')),
              ),
            ),
            const Divider(),
            const _BedtimeTile(),
            const Divider(),
            const _HealthTile(),
            const Divider(),
            const _ThemePickerCard(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Sömntips & tillbehör',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Saker som hjälper dig sova bättre — öppnar Amazon.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ..._tools.map(
              (p) => ListTile(
                leading: Text(p.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(p.name),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(
                  Uri.parse(_amazonUrl(p.query)),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Länkarna är affiliate-länkar — vi kan få en liten provision om du handlar, utan extra kostnad för dig.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Integritetspolicy'),
              onTap: () => launchUrl(
                Uri.parse(AppConstants.privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Användarvillkor'),
              onTap: () => launchUrl(
                Uri.parse(AppConstants.termsOfUseUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Support'),
              onTap: () => launchUrl(
                Uri.parse(AppConstants.supportUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Om appen'),
              subtitle: Text('Sömnkoll v1.0.0'),
            ),
            if (kDebugMode) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.orange),
                title: const Text('DEBUG: Aktivera premium (24h)'),
                subtitle: Text(premium.isPremium
                    ? 'Premium aktivt'
                    : 'För screenshot till App Store'),
                onTap: () async {
                  await premium.grantTemporaryPremium(
                      duration: const Duration(days: 30));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Debug premium aktiverat (30 dagar)')),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BedtimeTile extends StatefulWidget {
  const _BedtimeTile();

  @override
  State<_BedtimeTile> createState() => _BedtimeTileState();
}

class _BedtimeTileState extends State<_BedtimeTile> {
  TimeOfDay _time = const TimeOfDay(hour: 22, minute: 30);
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final time = await NotificationService.instance.getBedtime();
    final enabled = await NotificationService.instance.isBedtimeEnabled();
    if (!mounted) return;
    setState(() {
      _time = time;
      _enabled = enabled;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool v) async {
    if (v) {
      final granted =
          await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tillåt notiser i Inställningar för att aktivera')),
        );
        return;
      }
    }
    await NotificationService.instance.setBedtime(_time, enabled: v);
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    await NotificationService.instance.setBedtime(picked, enabled: _enabled);
    if (!mounted) return;
    setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const ListTile(
        leading: Icon(Icons.bedtime_outlined),
        title: Text('Läggdagspåminnelse'),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.bedtime_outlined),
          title: const Text('Läggdagspåminnelse'),
          subtitle: Text(_enabled
              ? 'Påminner kl. ${_time.format(context)}'
              : 'Av'),
          value: _enabled,
          onChanged: _toggle,
        ),
        if (_enabled)
          ListTile(
            leading: const SizedBox(width: 24),
            title: const Text('Tid'),
            trailing: Text(
              _time.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: _pickTime,
          ),
      ],
    );
  }
}

class _HealthTile extends StatefulWidget {
  const _HealthTile();

  @override
  State<_HealthTile> createState() => _HealthTileState();
}

class _HealthTileState extends State<_HealthTile> {
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await HealthService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool v) async {
    if (v) {
      final granted = await HealthService.instance.requestPermissions();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Aktivera skrivåtkomst i Hälsa-appen för att synka')),
        );
        return;
      }
    }
    await HealthService.instance.setEnabled(v);
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const ListTile(
        leading: Icon(Icons.favorite_outline),
        title: Text('Apple Health'),
      );
    }
    return SwitchListTile(
      secondary: const Icon(Icons.favorite_outline),
      title: const Text('Synka till Apple Health'),
      subtitle: Text(_enabled
          ? 'Sömnsessioner skrivs till Hälsa-appen'
          : 'Av — sömndata stannar i Sömnkoll'),
      value: _enabled,
      onChanged: _toggle,
    );
  }
}

class _AmazonProduct {
  final String emoji;
  final String name;
  final String query;
  const _AmazonProduct({
    required this.emoji,
    required this.name,
    required this.query,
  });
}

class _ThemePickerCard extends StatelessWidget {
  const _ThemePickerCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final premium = context.watch<PremiumService>();
    final canUse = premium.canUseThemes;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Färgtema',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (!canUse)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Premium',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColorTheme.values.map((t) {
                  final colors = ThemeService.themeColors[t]!;
                  final isSelected = theme.currentTheme == t;
                  final isDefault = t == AppColorTheme.midnight;
                  final locked = !canUse && !isDefault;

                  return GestureDetector(
                    onTap: locked
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PaywallScreen(
                                      source: 'themes')),
                            )
                        : () => theme.setTheme(t),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors['primary']!,
                                colors['secondary']!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: colors['primary']!, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colors['primary']!
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: locked
                              ? const Icon(Icons.lock,
                                  color: Colors.white, size: 18)
                              : isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 20)
                                  : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.themeName(t),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

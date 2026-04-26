import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_service.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';

class PaywallScreen extends StatelessWidget {
  final String source;
  const PaywallScreen({super.key, this.source = 'generic'});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.workspace_premium, size: 72, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Sömnkoll Premium',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Auto-spårning hela natten, avancerad ljudanalys, all historik '
              'och obegränsade ljudklipp – helt utan annonser.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _planTile(context, PremiumPlan.yearly, premium, lang,
                highlight: true),
            const SizedBox(height: 12),
            _planTile(context, PremiumPlan.monthly, premium, lang),
            const SizedBox(height: 12),
            _planTile(context, PremiumPlan.lifetime, premium, lang),
            const SizedBox(height: 20),
            if (!premium.isPremium) const _WatchAdCard(),
            const SizedBox(height: 20),
            TextButton(
              onPressed: premium.storeAvailable
                  ? () => premium.restorePurchases()
                  : null,
              child: const Text('Återställ köp'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Månadsprenumerationen förnyas automatiskt varje månad och '
                'årsprenumerationen varje år för samma pris. Livstid är ett '
                'engångsköp. Prenumerationen förnyas om den inte avbryts minst '
                '24 timmar före periodens slut. Betalning dras från ditt Apple '
                'ID. Hantera eller avsluta i Inställningar → [ditt namn] → '
                'Prenumerationer.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _openUrl(AppConstants.termsOfUseUrl),
                  child: const Text('Användarvillkor (EULA)'),
                ),
                const Text('·'),
                TextButton(
                  onPressed: () => _openUrl(AppConstants.privacyPolicyUrl),
                  child: const Text('Integritetspolicy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _planTile(BuildContext context, PremiumPlan plan,
      PremiumService premium, String lang,
      {bool highlight = false}) {
    final label = switch (plan) {
      PremiumPlan.monthly => 'Månadsvis',
      PremiumPlan.yearly => 'Årsvis',
      PremiumPlan.lifetime => 'Engångsköp',
      PremiumPlan.free => '',
    };
    final price = premium.getPrice(plan, lang);
    final trial = premium.introOfferText(plan, lang);
    final subtitleParts = <String>[
      ?trial,
      if (plan == PremiumPlan.yearly)
        '${premium.getMonthlyEquivalent(plan, lang)} · '
            'Spara ${premium.getYearlySavingsPercent(lang)}%',
    ];
    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join('\n');
    return Card(
      elevation: highlight ? 4 : 1,
      color: highlight ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        isThreeLine: subtitleParts.length > 1,
        title: Text(label),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: trial != null
                    ? const TextStyle(fontWeight: FontWeight.w600)
                    : null,
              ),
        trailing: Text(price,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        onTap: premium.purchaseInProgress
            ? null
            : () => premium.purchase(plan),
      ),
    );
  }
}

class _WatchAdCard extends StatefulWidget {
  const _WatchAdCard();

  @override
  State<_WatchAdCard> createState() => _WatchAdCardState();
}

class _WatchAdCardState extends State<_WatchAdCard> {
  bool _loading = false;

  Future<void> _watchAd() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final premium = context.read<PremiumService>();

    final rewarded = await AdService().showRewardedAd();
    if (!mounted) return;
    setState(() => _loading = false);

    if (rewarded) {
      await premium.grantTemporaryPremium(duration: const Duration(hours: 24));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('24 timmar gratis premium aktiverat! 🎉'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ingen annons tillgänglig just nu, försök igen snart.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: const Text('Titta på en annons'),
        subtitle: const Text('Få 24 timmar premium gratis'),
        trailing: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: _loading ? null : _watchAd,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/affiliate_service.dart';

class AffiliateToolsCard extends StatelessWidget {
  final Color accent;
  final String? tag;
  final String title;
  final IconData icon;

  const AffiliateToolsCard({
    super.key,
    required this.accent,
    this.tag,
    this.title = 'Sov bättre med rätt prylar',
    this.icon = Icons.bedtime_rounded,
  });

  Future<void> _open(String query) async {
    final uri = Uri.parse(AffiliateService.amazonUrl(query));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final products = AffiliateService.productsFor(tag: tag);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Handplockade tips — öppnar Amazon.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...products.map(
            (p) => InkWell(
              onTap: () => _open(p.query),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 18, color: accent),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text(
              'Affiliate-länkar — vi kan få en liten provision om du handlar, '
              'utan extra kostnad för dig.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

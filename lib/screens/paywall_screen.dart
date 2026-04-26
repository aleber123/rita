import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/modules_catalog.dart';
import '../services/module_service.dart';
import '../utils/app_theme.dart';
import '../widgets/parental_gate.dart';

/// "Lås upp allt" paywall — auto-renewable subscription with monthly and
/// yearly options. Per Apple guidelines, the screen lists price, period,
/// auto-renewal note, and links to terms.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selected = ModulesCatalog.subscriptionYearly;

  Future<void> _onUnlock(ModuleService service) async {
    final ok = await ParentalGate.show(context);
    if (!ok || !mounted) return;
    await service.purchaseSubscription(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Lås upp allt'),
        backgroundColor: AppTheme.cream,
        elevation: 0,
      ),
      body: Consumer<ModuleService>(
        builder: (context, service, _) {
          if (service.hasActiveSubscription) {
            return _ActiveView(service: service);
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text('🎨', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 12),
                  const Text(
                    'Lås upp alla teckningar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enhörningar, superhjältar, djur, fordon och dinosaurier '
                    '— allt nytt vi lägger till ingår.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  _PlanCard(
                    productId: ModulesCatalog.subscriptionYearly,
                    title: 'År',
                    subtitle: 'Bästa värde',
                    price: service.priceFor(
                      ModulesCatalog.subscriptionYearly,
                      fallback: '349 kr/år',
                    ),
                    selected: _selected == ModulesCatalog.subscriptionYearly,
                    onTap: () => setState(
                      () => _selected = ModulesCatalog.subscriptionYearly,
                    ),
                    accent: AppTheme.berry,
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    productId: ModulesCatalog.subscriptionMonthly,
                    title: 'Månad',
                    subtitle: 'Säg upp när du vill',
                    price: service.priceFor(
                      ModulesCatalog.subscriptionMonthly,
                      fallback: '39 kr/mån',
                    ),
                    selected: _selected == ModulesCatalog.subscriptionMonthly,
                    onTap: () => setState(
                      () => _selected = ModulesCatalog.subscriptionMonthly,
                    ),
                    accent: AppTheme.sky,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed:
                          service.purchasing ? null : () => _onUnlock(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.berry,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: service.purchasing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Starta prenumeration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: service.purchasing
                        ? null
                        : () async {
                            final ok = await ParentalGate.show(context);
                            if (!ok) return;
                            await service.restore();
                          },
                    child: const Text('Återställ köp'),
                  ),
                  if (service.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Något gick fel. Försök igen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Prenumerationen förnyas automatiskt om den inte sägs '
                    'upp minst 24 timmar före perioden tar slut. Hantera '
                    'eller säg upp i App Store-inställningar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String productId;
  final String title;
  final String subtitle;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const _PlanCard({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? accent : Colors.black12,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? accent : Colors.black38,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  final ModuleService service;
  const _ActiveView({required this.service});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            const Text(
              'Premium aktiv',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alla teckningar är upplåsta. Tack för att du stöttar Rita!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hantera prenumerationen i App Store-inställningar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

/// Apple-approved parental gate for IAP and other parent-only flows.
/// Shows a math question that a 3–5-year-old can't solve, but a parent can
/// in a second. Returns true if parent answered correctly.
class ParentalGate extends StatefulWidget {
  const ParentalGate({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ParentalGate(),
    );
    return result ?? false;
  }

  @override
  State<ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<ParentalGate> {
  late final int _a;
  late final int _b;
  late final List<int> _choices;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _a = 4 + r.nextInt(8); // 4..11
    _b = 4 + r.nextInt(8); // 4..11
    final correct = _a + _b;
    final options = <int>{
      correct,
      correct + 1 + r.nextInt(3),
      correct - 1 - r.nextInt(3),
      correct + 5,
    };
    _choices = options.toList()..shuffle();
  }

  void _pick(int value) {
    if (value == _a + _b) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Försök igen, fråga en vuxen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Endast för vuxna',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lös för att fortsätta',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Text(
              '$_a + $_b = ?',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _choices
                  .map((c) => SizedBox(
                        width: 88,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: () => _pick(c),
                          child: Text(
                            '$c',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Avbryt'),
            ),
          ],
        ),
      ),
    );
  }
}

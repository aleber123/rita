import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../data/sleep_sounds.dart';
import '../services/premium_service.dart';
import '../utils/app_theme.dart';
import 'paywall_screen.dart';

class SleepSoundsScreen extends StatefulWidget {
  const SleepSoundsScreen({super.key});

  @override
  State<SleepSoundsScreen> createState() => _SleepSoundsScreenState();
}

class _SleepSoundsScreenState extends State<SleepSoundsScreen> {
  final AudioPlayer _player = AudioPlayer()..setLoopMode(LoopMode.one);
  String? _playingId;
  double _volume = 0.7;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(SleepSound sound) async {
    if (_playingId == sound.id) {
      await _player.pause();
      setState(() => _playingId = null);
      return;
    }
    try {
      await _player.setAsset(sound.assetPath);
      await _player.setVolume(_volume);
      await _player.play();
      setState(() => _playingId = sound.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ljudfilen är inte tillgänglig ännu (${sound.assetPath})',
          ),
        ),
      );
    }
  }

  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PaywallScreen(source: 'sleep_sounds'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumService>().isPremium;
    return Scaffold(
      appBar: AppBar(title: const Text('Sömnljud')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0F1E), Color(0xFF1A1F3D)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            ...kSleepSounds.map((s) => _SoundTile(
                  sound: s,
                  playing: _playingId == s.id,
                  locked: s.premium && !isPremium,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (s.premium && !isPremium) {
                      _openPaywall();
                    } else {
                      _toggle(s);
                    }
                  },
                )),
            const SizedBox(height: 16),
            if (_playingId != null) _VolumeSlider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                _player.setVolume(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  final SleepSound sound;
  final bool playing;
  final bool locked;
  final VoidCallback onTap;

  const _SoundTile({
    required this.sound,
    required this.playing,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: playing
                  ? scheme.primary.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.06),
              width: playing ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(sound.emoji,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sound.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sound.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                locked
                    ? Icons.workspace_premium
                    : (playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded),
                size: 36,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _VolumeSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded, color: Colors.white70),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
          ),
          const Icon(Icons.volume_up_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

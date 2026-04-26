/// Catalog of bundled sleep sounds. Drop matching MP3 files into
/// `assets/sounds/` (paths must match `assetPath`) — they will start playing
/// from the sleep-sounds screen. Two are free, the rest are premium.
class SleepSound {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final String assetPath;
  final bool premium;

  const SleepSound({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.assetPath,
    required this.premium,
  });
}

const List<SleepSound> kSleepSounds = [
  SleepSound(
    id: 'rain',
    title: 'Regn mot fönster',
    description: 'Mjukt regn — klassisk insomningshjälp',
    emoji: '🌧️',
    assetPath: 'assets/sounds/rain.mp3',
    premium: false,
  ),
  SleepSound(
    id: 'white_noise',
    title: 'Vitt brus',
    description: 'Konstant frekvens som maskerar omgivningsljud',
    emoji: '📻',
    assetPath: 'assets/sounds/white_noise.mp3',
    premium: false,
  ),
  SleepSound(
    id: 'forest',
    title: 'Skog vid gryning',
    description: 'Fågelsång och vind genom löv',
    emoji: '🌲',
    assetPath: 'assets/sounds/forest.mp3',
    premium: true,
  ),
  SleepSound(
    id: 'ocean',
    title: 'Vågor mot stranden',
    description: 'Långsamma havsvågor',
    emoji: '🌊',
    assetPath: 'assets/sounds/ocean.mp3',
    premium: true,
  ),
  SleepSound(
    id: 'fireplace',
    title: 'Brinnande brasa',
    description: 'Sprakande eld och varma toner',
    emoji: '🔥',
    assetPath: 'assets/sounds/fireplace.mp3',
    premium: true,
  ),
  SleepSound(
    id: 'thunderstorm',
    title: 'Åskväder',
    description: 'Avlägsen åska och regn',
    emoji: '⛈️',
    assetPath: 'assets/sounds/thunderstorm.mp3',
    premium: true,
  ),
  SleepSound(
    id: 'pink_noise',
    title: 'Rosa brus',
    description: 'Mjukare än vitt brus — bättre för djupsömn',
    emoji: '🎵',
    assetPath: 'assets/sounds/pink_noise.mp3',
    premium: true,
  ),
  SleepSound(
    id: 'lullaby',
    title: 'Vaggvisa',
    description: 'Lugn pianomelodi för småbarn och vuxna',
    emoji: '🎼',
    assetPath: 'assets/sounds/lullaby.mp3',
    premium: true,
  ),
];

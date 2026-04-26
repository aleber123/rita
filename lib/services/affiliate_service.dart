class AffiliateProduct {
  final String emoji;
  final String name;
  final String query;
  const AffiliateProduct(this.emoji, this.name, this.query);
}

class AffiliateService {
  static const String amazonTag = 'alexanderbe05-21';

  static String amazonUrl(String query) {
    final q = Uri.encodeComponent(query);
    return 'https://www.amazon.se/s?k=$q&tag=$amazonTag';
  }

  static const List<AffiliateProduct> _general = [
    AffiliateProduct('🛏️', 'Memoryskum-kuddar', 'memoryskum kudde nackstöd'),
    AffiliateProduct('😴', 'Vit brusmaskin', 'white noise machine sömn'),
    AffiliateProduct('🌙', 'Sömnmask av silke', 'sömnmask silke ögonmask'),
  ];

  static const Map<String, List<AffiliateProduct>> _byCategory = {
    'sleep_environment': [
      AffiliateProduct('🌙', 'Sömnmask av silke', 'sömnmask silke ögonmask blockerar ljus'),
      AffiliateProduct('🎧', 'Sömnhörlurar', 'sleep headphones bluetooth pannband'),
      AffiliateProduct('🔇', 'Vit brusmaskin', 'white noise machine ljudmaskin sovrum'),
      AffiliateProduct('🌡️', 'Sovrumstermometer', 'rumstermometer hygrometer sovrum'),
    ],
    'mattress_pillow': [
      AffiliateProduct('🛏️', 'Memoryskum-kudde', 'memoryskum kudde nackstöd ergonomisk'),
      AffiliateProduct('🪶', 'Dunkudde', 'dunkudde fjäderkudde sovkudde'),
      AffiliateProduct('🧸', 'Bäddmadrass', 'bäddmadrass topper memoryskum'),
      AffiliateProduct('🛋️', 'Tyngdtäcke', 'tyngdtäcke vuxen sömn'),
    ],
    'bedding': [
      AffiliateProduct('🛌', 'Lakanset bambu', 'lakan bambu påslakanset svalt'),
      AffiliateProduct('🧣', 'Påslakan i lin', 'påslakan lin sovrum andningsbart'),
      AffiliateProduct('🪶', 'Dunkudde 50x60', 'dunkudde 50x60 hotellkänsla'),
    ],
    'aromatherapy': [
      AffiliateProduct('💧', 'Aromaterapi-diffuser', 'aromadiffuser eterisk olja sovrum'),
      AffiliateProduct('🌿', 'Lavendelolja', 'lavendelolja eterisk sömn'),
      AffiliateProduct('🕯️', 'Sömnljus lavendel', 'lavender ljus sovrum aromaterapi'),
    ],
    'tea_supplements': [
      AffiliateProduct('🍵', 'Sömn-te (kamomill)', 'kamomill te sömn lugnande'),
      AffiliateProduct('💊', 'Magnesium tabletter', 'magnesium sömn tablett'),
      AffiliateProduct('🌙', 'Melatonin (receptfritt)', 'melatonin tablett sömn'),
      AffiliateProduct('🧴', 'Valerian rot kapslar', 'vänderot valerian kapslar'),
    ],
    'lighting': [
      AffiliateProduct('🌅', 'Soluppgångslampa (wake light)', 'wake up light soluppgångslampa väckarklocka'),
      AffiliateProduct('💡', 'Smart varmvit lampa', 'smart lampa varmvit tunable e27'),
      AffiliateProduct('🕯️', 'Saltkristalllampa', 'saltkristall lampa sovrum'),
    ],
    'sound': [
      AffiliateProduct('🎧', 'Bluetooth pannband-hörlurar', 'sleep headphones bluetooth pannband'),
      AffiliateProduct('🔇', 'Vit brusmaskin', 'white noise machine sömn'),
      AffiliateProduct('🎶', 'Bluetooth-högtalare nattduksbord', 'bluetooth högtalare nattduksbord'),
    ],
    'snoring': [
      AffiliateProduct('👃', 'Nässtrips anti-snarkning', 'näsplåster nässtrips snarkning'),
      AffiliateProduct('💍', 'Anti-snark ring', 'anti snarkning ring akupressur'),
      AffiliateProduct('🛏️', 'Sidoläges-kudde', 'sidoläges kudde anti snarkning'),
    ],
    'wake_alarm': [
      AffiliateProduct('⏰', 'Smart väckarklocka', 'smart väckarklocka soluppgång'),
      AffiliateProduct('🌅', 'Soluppgångslampa', 'wake up light soluppgångslampa'),
      AffiliateProduct('📱', 'Vibrerande väckare för par', 'vibrerande väckarklocka armband'),
    ],
    'bedroom_air': [
      AffiliateProduct('🌬️', 'Luftrenare HEPA', 'luftrenare hepa sovrum'),
      AffiliateProduct('💧', 'Luftfuktare', 'luftfuktare sovrum tyst'),
      AffiliateProduct('🌡️', 'Hygrometer', 'hygrometer rumstermometer sovrum'),
    ],
  };

  /// Map context tag → category.
  static const Map<String, String> _tagToCategory = {
    'snore': 'snoring',
    'mask': 'sleep_environment',
    'noise': 'sound',
    'pillow': 'mattress_pillow',
    'mattress': 'mattress_pillow',
    'aroma': 'aromatherapy',
    'tea': 'tea_supplements',
    'supplement': 'tea_supplements',
    'lamp': 'lighting',
    'wake': 'wake_alarm',
    'alarm': 'wake_alarm',
    'air': 'bedroom_air',
    'bed': 'bedding',
  };

  /// Returns 3-4 contextual products for the given context tag.
  static List<AffiliateProduct> productsFor({String? tag}) {
    if (tag != null && _tagToCategory.containsKey(tag)) {
      final category = _tagToCategory[tag]!;
      return _byCategory[category] ?? _general;
    }
    return _general;
  }

  /// Returns the carousel of all sleep categories for a "shop" view.
  static Map<String, List<AffiliateProduct>> get categories => _byCategory;

  /// Friendly Swedish category names for the shop view.
  static const Map<String, String> categoryLabels = {
    'sleep_environment': 'Sovmiljö',
    'mattress_pillow': 'Madrass & kuddar',
    'bedding': 'Sängkläder',
    'aromatherapy': 'Aromaterapi',
    'tea_supplements': 'Te & kosttillskott',
    'lighting': 'Belysning',
    'sound': 'Ljud',
    'snoring': 'Mot snarkning',
    'wake_alarm': 'Väckarklockor',
    'bedroom_air': 'Sovrumsluft',
  };
}

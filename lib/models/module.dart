import 'drawing.dart';

/// A pack of coloring pages (e.g. Unicorns, Superhjältar). Modules are
/// either bundled free or unlocked via a one-shot IAP keyed by [productId].
class DrawingModule {
  final String id;
  final String title;
  final String emoji;
  final List<Drawing> drawings;

  /// IAP product id (App Store / Play). Null = bundled free.
  final String? productId;

  const DrawingModule({
    required this.id,
    required this.title,
    required this.emoji,
    required this.drawings,
    this.productId,
  });

  bool get isFree => productId == null;
}

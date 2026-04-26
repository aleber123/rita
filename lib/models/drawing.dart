/// A single coloring page within a module. The asset is a black-on-white
/// PNG line art that the kid colors in freehand on top of via
/// [LineArtCanvas].
class Drawing {
  final String id;
  final String title;
  final String assetPath;

  const Drawing({
    required this.id,
    required this.title,
    required this.assetPath,
  });
}

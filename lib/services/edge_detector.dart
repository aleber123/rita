import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Turns a photo into kid-friendly black-on-white line art using Sobel
/// edge detection followed by thresholding. Pure pixel math — no ML, no
/// network calls, nothing leaves the device.
class EdgeDetector {
  /// Maximum edge of the processed image. Smaller = faster + less detail
  /// (which is what we want — kids can't color tiny edges).
  static const int _maxEdge = 1024;

  /// Higher thresholds keep only the strongest contours.
  static const int _edgeThreshold = 60;

  /// Run the pipeline off the UI thread.
  static Future<Uint8List> processBytes(Uint8List input) {
    return compute(_processBytesIsolate, input);
  }
}

Uint8List _processBytesIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Kunde inte tolka bilden');
  }

  // Strip EXIF orientation so the saved PNG matches what the camera UI
  // showed the user.
  var image = img.bakeOrientation(decoded);

  // Downscale large images so processing stays fast on phones.
  final longest =
      image.width >= image.height ? image.width : image.height;
  if (longest > EdgeDetector._maxEdge) {
    final scale = EdgeDetector._maxEdge / longest;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  // Soft blur smooths skin/noise so we don't pick up every pore.
  image = img.gaussianBlur(image, radius: 2);
  image = img.grayscale(image);

  final w = image.width;
  final h = image.height;

  // Pull luminance into a flat byte array — much faster than getPixel
  // inside the inner Sobel loop.
  final lum = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      lum[y * w + x] = p.r.toInt();
    }
  }

  // Sobel — produce a binary edge mask. Edge pixels become black, the
  // rest white, matching a coloring book page.
  final out = img.Image(width: w, height: h, numChannels: 4);
  final white = img.ColorRgba8(255, 255, 255, 255);
  final black = img.ColorRgba8(0, 0, 0, 255);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        out.setPixel(x, y, white);
        continue;
      }
      final tl = lum[(y - 1) * w + (x - 1)];
      final tc = lum[(y - 1) * w + x];
      final tr = lum[(y - 1) * w + (x + 1)];
      final ml = lum[y * w + (x - 1)];
      final mr = lum[y * w + (x + 1)];
      final bl = lum[(y + 1) * w + (x - 1)];
      final bc = lum[(y + 1) * w + x];
      final br = lum[(y + 1) * w + (x + 1)];

      final gx = -tl - 2 * ml - bl + tr + 2 * mr + br;
      final gy = -tl - 2 * tc - tr + bl + 2 * bc + br;
      final mag = (gx.abs() + gy.abs());

      out.setPixel(x, y, mag > EdgeDetector._edgeThreshold ? black : white);
    }
  }

  return Uint8List.fromList(img.encodePng(out));
}

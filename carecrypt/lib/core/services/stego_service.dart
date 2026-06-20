import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// LSB (Least Significant Bit) Steganography
/// Hides encrypted report data inside a PNG image.
///
/// NEW: generateCoverImage() creates a local synthetic cover image
/// guaranteed to be large enough — no user photo needed.
class StegoService {
  // Payload format: [4-byte big-endian length header][data bytes]

  /// Auto-generates a cover image large enough for [data] and hides data in it.
  /// Uses a deterministic perlin-like noise pattern seeded from the data hash
  /// so the cover looks like a plausible medical scan thumbnail.
  /// Returns PNG bytes with data embedded in pixel LSBs.
  static Uint8List hideDataAuto(Uint8List data) {
    final coverImage = generateCoverImage(data.length);
    return _embedData(coverImage, data);
  }

  /// Generate a synthetic cover image large enough to hold [dataBytes] of payload.
  /// Uses a multi-tone noise pattern — visually indistinguishable from noise.
  static img.Image generateCoverImage(int dataBytes) {
    // Each pixel stores 3 bits (R,G,B LSBs). Add 4-byte (32-bit) header.
    final totalBitsNeeded = (dataBytes + 4) * 8;
    final pixelsNeeded = (totalBitsNeeded / 3).ceil();

    // Calculate square image dimensions with 20% safety margin
    final side = (sqrt(pixelsNeeded * 1.2)).ceil();
    final width = max(side, 64);   // minimum 64×64
    final height = max(side, 64);

    final image = img.Image(width: width, height: height);
    final rng = Random(dataBytes); // seeded determinism

    // Fill with layered noise for a "medical scan" look
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Base gradient
        final base = ((x * 180) ~/ width + (y * 60) ~/ height) % 256;
        // Noise layer
        final noise = rng.nextInt(80);
        // Slight horizontal scan-line pattern (mimics X-ray texture)
        final scanLine = (y % 4 == 0) ? 10 : 0;

        final r = (base + noise - scanLine).clamp(30, 220);
        final g = ((base * 0.9).toInt() + noise ~/ 2).clamp(30, 200);
        final b = ((base * 0.8).toInt() + noise ~/ 3 + 20).clamp(40, 230);

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  /// Hide [data] bytes inside a user-supplied [coverImageBytes] (PNG/JPEG).
  /// If the image is too small, auto-enlarges by padding with generated pixels.
  static Uint8List hideData(Uint8List coverImageBytes, Uint8List data) {
    var image = img.decodeImage(coverImageBytes);
    if (image == null) throw Exception('Invalid cover image');

    final payload = _buildPayload(data);
    final bitsNeeded = payload.length * 8;
    final maxBits = image.width * image.height * 3;

    // Auto-resize: if user's cover image is too small, composite it onto a
    // generated canvas of sufficient size
    if (bitsNeeded > maxBits) {
      final generated = generateCoverImage(data.length);
      // Copy user image pixels into top-left of generated canvas for authenticity
      final copyW = min(image.width, generated.width);
      final copyH = min(image.height, generated.height);
      img.compositeImage(generated, image,
        dstX: 0, dstY: 0, srcW: copyW, srcH: copyH);
      image = generated;
    }

    return _embedData(image, data);
  }

  /// Extract hidden data from a stego image.
  static Uint8List extractData(Uint8List stegoImageBytes) {
    final image = img.decodeImage(stegoImageBytes);
    if (image == null) throw Exception('Invalid stego image');

    final bits = <int>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        bits.add(pixel.r.toInt() & 1);
        bits.add(pixel.g.toInt() & 1);
        bits.add(pixel.b.toInt() & 1);
      }
    }

    return _extractPayload(bits);
  }

  // ─── Private helpers ─────────────────────────────────────

  static Uint8List _embedData(img.Image image, Uint8List data) {
    final payload = _buildPayload(data);
    final bits = _bytesToBits(payload);

    final maxBits = image.width * image.height * 3;
    if (bits.length > maxBits) {
      throw Exception(
          'Data too large even after auto-resize: ${bits.length} bits > $maxBits available');
    }

    int bitIndex = 0;
    outer:
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (bitIndex >= bits.length) break outer;
        final pixel = image.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        if (bitIndex < bits.length) r = (r & 0xFE) | bits[bitIndex++];
        if (bitIndex < bits.length) g = (g & 0xFE) | bits[bitIndex++];
        if (bitIndex < bits.length) b = (b & 0xFE) | bits[bitIndex++];

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  static Uint8List _buildPayload(Uint8List data) {
    final length = data.length;
    final header = Uint8List(4)
      ..[0] = (length >> 24) & 0xFF
      ..[1] = (length >> 16) & 0xFF
      ..[2] = (length >> 8) & 0xFF
      ..[3] = length & 0xFF;
    return Uint8List.fromList([...header, ...data]);
  }

  static Uint8List _extractPayload(List<int> bits) {
    if (bits.length < 32) throw Exception('Image too small');

    final lengthBytes = _bitsToBytes(bits.sublist(0, 32));
    final length = (lengthBytes[0] << 24) |
        (lengthBytes[1] << 16) |
        (lengthBytes[2] << 8) |
        lengthBytes[3];

    if (length <= 0 || length > 50 * 1024 * 1024) {
      throw Exception('Invalid payload length: $length');
    }

    final dataBits = bits.sublist(32, 32 + length * 8);
    return _bitsToBytes(dataBits);
  }

  static List<int> _bytesToBits(Uint8List bytes) {
    final bits = <int>[];
    for (final byte in bytes) {
      for (int i = 7; i >= 0; i--) {
        bits.add((byte >> i) & 1);
      }
    }
    return bits;
  }

  static Uint8List _bitsToBytes(List<int> bits) {
    final bytes = Uint8List(bits.length ~/ 8);
    for (int i = 0; i < bytes.length; i++) {
      int byte = 0;
      for (int j = 0; j < 8; j++) {
        byte = (byte << 1) | bits[i * 8 + j];
      }
      bytes[i] = byte;
    }
    return bytes;
  }
}

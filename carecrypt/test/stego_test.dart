import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:carecrypt/core/services/stego_service.dart';

void main() {
  group('StegoService Tests', () {
    test('Should hide and extract text payload correctly', () {
      final originalText = 'CareCrypt Secure Lab Report AES Encrypted Payload 12345!';
      final originalBytes = Uint8List.fromList(originalText.codeUnits);

      // Hide data
      final stegoImageBytes = StegoService.hideDataAuto(originalBytes);
      expect(stegoImageBytes, isNotNull);
      expect(stegoImageBytes.length, greaterThan(0));

      // Extract data
      final extractedBytes = StegoService.extractData(stegoImageBytes);
      final extractedText = String.fromCharCodes(extractedBytes);

      expect(extractedText, equals(originalText));
    });

    test('Should handle auto-resizing when cover image is too small', () {
      // Create a valid tiny 10x10 cover image programmatically
      final tinyImg = img.Image(width: 10, height: 10);
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          tinyImg.setPixelRgb(x, y, 100, 100, 100);
        }
      }
      final tinyPng = Uint8List.fromList(img.encodePng(tinyImg));

      // Payload that needs more pixels than a 10x10 image can hold
      final largeText = 'A' * 200;
      final dataBytes = Uint8List.fromList(largeText.codeUnits);

      final stegoBytes = StegoService.hideData(tinyPng, dataBytes);
      final extracted = StegoService.extractData(stegoBytes);

      expect(String.fromCharCodes(extracted), equals(largeText));
    });
  });
}

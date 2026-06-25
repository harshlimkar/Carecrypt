import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache decrypted patient lab report PDFs locally.
class PdfCacheService {
  static final Map<String, Uint8List> _memCache = {};

  /// Caches the PDF bytes in memory and persists them to SharedPreferences.
  static Future<void> cacheReport(String requestId, Uint8List pdfBytes) async {
    _memCache[requestId] = pdfBytes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_pdf_$requestId', base64Encode(pdfBytes));
    } catch (_) {
      // Fail silently if storage is full or unavailable
    }
  }

  /// Retrieves the cached PDF bytes, checking memory first, then SharedPreferences.
  static Future<Uint8List?> getReport(String requestId) async {
    // Try mem cache first
    if (_memCache.containsKey(requestId)) {
      return _memCache[requestId];
    }

    // Try persisted storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64Str = prefs.getString('cached_pdf_$requestId');
      if (base64Str != null && base64Str.isNotEmpty) {
        final bytes = base64Decode(base64Str);
        _memCache[requestId] = bytes;
        return bytes;
      }
    } catch (_) {
      // Fail silently
    }
    return null;
  }

  /// Clears the caches (e.g. on logout for patient security).
  static Future<void> clearAll() async {
    _memCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('cached_pdf_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}

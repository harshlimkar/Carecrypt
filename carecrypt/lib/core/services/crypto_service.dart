import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:convert/convert.dart';

class CryptoService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─────────────────────────────────────────────────────────
  // AES-256-GCM  (Patient records, prescriptions, reports)
  // ─────────────────────────────────────────────────────────
  static final _aesGcm = AesGcm.with256bits();

  static Future<String> encryptAesGcm(String plaintext, {String? keyAlias}) async {
    SecretKey secretKey;
    if (keyAlias != null) {
      final storedKey = await _storage.read(key: keyAlias);
      if (storedKey != null) {
        secretKey = SecretKey(base64Decode(storedKey));
      } else {
        secretKey = await _aesGcm.newSecretKey();
        await _storage.write(key: keyAlias, value: base64Encode(await secretKey.extractBytes()));
      }
    } else {
      secretKey = await _aesGcm.newSecretKey();
    }

    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    final result = {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      if (keyAlias == null) 'key': base64Encode(await secretKey.extractBytes()),
    };
    return jsonEncode(result);
  }

  static Future<String> decryptAesGcm(String encryptedJson, {String? keyAlias, String? keyBase64}) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(encryptedJson);
    } catch (e) {
      throw FormatException('Invalid JSON payload in encrypted content: $e');
    }

    if (decoded is! Map) {
      throw const FormatException('Encrypted payload is not a JSON object');
    }

    final map = decoded;
    final cipherTextStr = map['ciphertext'];
    final nonceStr = map['nonce'];
    final macStr = map['mac'];

    if (cipherTextStr is! String || nonceStr is! String || macStr is! String) {
      throw const FormatException('Missing AES ciphertext, nonce, or mac in payload');
    }

    final cipherText = base64Decode(cipherTextStr);
    final nonce = base64Decode(nonceStr);
    final mac = base64Decode(macStr);

    List<int> keyBytes;
    if (keyAlias != null) {
      final stored = await _storage.read(key: keyAlias);
      if (stored == null) {
        throw StateError('Decryption key not found in secure storage for alias: $keyAlias');
      }
      keyBytes = base64Decode(stored);
    } else if (keyBase64 != null) {
      keyBytes = base64Decode(keyBase64);
    } else {
      final keyStr = map['key'];
      if (keyStr is! String) {
        throw const FormatException('No embedded AES key found in payload');
      }
      keyBytes = base64Decode(keyStr);
    }

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    final clearText = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(clearText);
  }

  // ─────────────────────────────────────────────────────────
  // Ed25519  (Prescription & report signatures)
  // ─────────────────────────────────────────────────────────
  static final _ed25519 = Ed25519();

  static Future<Map<String, String>> generateEd25519KeyPair() async {
    final keyPair = await _ed25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    return {
      'privateKey': base64Encode(privateKeyBytes),
      'publicKey': base64Encode(publicKey.bytes),
    };
  }

  static Future<String> signEd25519(String data, String privateKeyBase64) async {
    final privateKeyBytes = base64Decode(privateKeyBase64);
    final keyPair = await _ed25519.newKeyPairFromSeed(privateKeyBytes.sublist(0, 32));
    final signature = await _ed25519.sign(utf8.encode(data), keyPair: keyPair);
    return base64Encode(signature.bytes);
  }

  static Future<bool> verifyEd25519(String data, String signatureBase64, String publicKeyBase64) async {
    try {
      final sigBytes = base64Decode(signatureBase64);
      final pubKeyBytes = base64Decode(publicKeyBase64);
      final publicKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(sigBytes, publicKey: publicKey);
      return await _ed25519.verify(utf8.encode(data), signature: signature);
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // X25519  (NFC session key exchange)
  // ─────────────────────────────────────────────────────────
  static final _x25519 = X25519();

  static Future<Map<String, String>> generateX25519KeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    return {
      'privateKey': base64Encode(privateKeyBytes),
      'publicKey': base64Encode(publicKey.bytes),
    };
  }

  static Future<String> deriveSharedSecret(String myPrivateKeyBase64, String theirPublicKeyBase64) async {
    final privateKeyBytes = base64Decode(myPrivateKeyBase64);
    final publicKeyBytes = base64Decode(theirPublicKeyBase64);
    final keyPair = await _x25519.newKeyPairFromSeed(privateKeyBytes);
    final remotePublicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519);
    final sharedSecret = await _x25519.sharedSecretKey(keyPair: keyPair, remotePublicKey: remotePublicKey);
    return base64Encode(await sharedSecret.extractBytes());
  }

  // ─────────────────────────────────────────────────────────
  // SHA-256  (Integrity verification, tamper detection)
  // ─────────────────────────────────────────────────────────
  static Future<String> sha256Hash(Uint8List data) async {
    final sha256 = Sha256();
    final hash = await sha256.hash(data);
    return hex.encode(hash.bytes);
  }

  static Future<String> sha256String(String data) async {
    return sha256Hash(Uint8List.fromList(utf8.encode(data)));
  }

  static Future<bool> verifyHash(Uint8List data, String expectedHash) async {
    final actualHash = await sha256Hash(data);
    return actualHash == expectedHash;
  }

  // ─────────────────────────────────────────────────────────
  // Key Storage helpers
  // ─────────────────────────────────────────────────────────
  static Future<void> storeKey(String alias, String value) async {
    await _storage.write(key: alias, value: value);
  }

  static Future<String?> loadKey(String alias) async {
    return _storage.read(key: alias);
  }

  static Future<void> deleteKey(String alias) async {
    await _storage.delete(key: alias);
  }

  static Future<void> clearAllKeys() async {
    await _storage.deleteAll();
  }
}

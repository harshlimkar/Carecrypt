import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Result of a biometric authentication attempt.
enum BiometricResult {
  /// Authentication succeeded via device biometrics / PIN.
  success,

  /// Authentication failed (user rejected, too many attempts).
  failed,

  /// Hardware is absent or biometrics not enrolled — caller should show
  /// the simulated authentication sheet for demo / fallback flow.
  needsSimulation,
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // ──────────────────────────────────────────────────────
  // Capability checks
  // ──────────────────────────────────────────────────────

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  static Future<List<BiometricType>> availableTypes() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────
  // Core authenticate — returns rich BiometricResult
  // ──────────────────────────────────────────────────────

  /// Attempt device biometric / PIN authentication.
  /// Returns:
  ///  - [BiometricResult.success]          → auth passed
  ///  - [BiometricResult.failed]           → user cancelled / failed
  ///  - [BiometricResult.needsSimulation]  → no biometric hardware; show demo UI
  static Future<BiometricResult> authenticateRich({
    String reason = 'Verify your identity to access CareCrypt',
  }) async {
    // Web never has real biometrics → always use simulation
    if (kIsWeb) return BiometricResult.needsSimulation;

    final available = await isAvailable();
    if (!available) return BiometricResult.needsSimulation;

    try {
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // allow device PIN as fallback inside OS dialog
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      return result ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      // NotAvailable / NotEnrolled / PasscodeNotSet → simulation
      const simCodes = {'NotAvailable', 'NotEnrolled', 'PasscodeNotSet'};
      if (simCodes.contains(e.code)) return BiometricResult.needsSimulation;
      // LockedOut / PermanentlyLockedOut → failed (not simulation)
      return BiometricResult.failed;
    }
  }

  // ──────────────────────────────────────────────────────
  // Convenience helpers (keep backward compatibility)
  // ──────────────────────────────────────────────────────

  /// Legacy bool helper — returns true only on real success.
  static Future<bool> authenticate({
    String reason = 'Verify your identity to access CareCrypt',
  }) async {
    final result = await authenticateRich(reason: reason);
    return result == BiometricResult.success;
  }

  static Future<BiometricResult> authenticateForQr() => authenticateRich(
        reason: 'Scan your fingerprint to generate secure prescription QR code',
      );

  static Future<BiometricResult> authenticateForRecords() => authenticateRich(
        reason: 'Verify your identity to access sensitive health records',
      );
}

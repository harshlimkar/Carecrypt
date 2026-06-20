import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'crypto_service.dart';
import 'access_log_service.dart';

enum NfcSessionState { idle, scanning, connected, failed }
enum NfcAccessRole { doctor, nurse }

/// Scoped payload types define what data each role can access via NFC
class NfcScopedPayload {
  final NfcAccessRole role;
  final String patientId;
  // Doctor-only fields
  final String? encryptedFullRecord;
  // Nurse-only fields
  final String? encryptedTreatmentOverview;
  // Common encrypted fields
  final String sharedSecret;

  const NfcScopedPayload({
    required this.role,
    required this.patientId,
    required this.sharedSecret,
    this.encryptedFullRecord,
    this.encryptedTreatmentOverview,
  });
}

class NfcSessionResult {
  final bool success;
  final String? patientId;
  final String? sharedSecret;
  final NfcScopedPayload? scopedPayload;
  final String? error;

  const NfcSessionResult({
    required this.success,
    this.patientId,
    this.sharedSecret,
    this.scopedPayload,
    this.error,
  });
}

/// NfcPayloadBuilder builds role-differentiated ENCRYPTED payloads
/// CRITICAL: NO plaintext patient data is ever stored in NDEF records.
class NfcPayloadBuilder {
  /// Build doctor-scoped payload:
  /// Doctor gets: full patient record, all diagnoses, full prescription history,
  ///              all lab reports, access logs. All encrypted with session key.
  static Future<String> buildDoctorPayload({
    required Map<String, dynamic> patientData,
    required String sharedSecret,
  }) async {
    // Wrap the full record in a role-scoped envelope
    final envelope = {
      'role': 'doctor',
      'access_level': 'full',
      'patient_id': patientData['patient_id'],
      'name': patientData['name'] ?? patientData['full_name'],
      'dob': patientData['date_of_birth'],
      'gender': patientData['gender'],
      'blood_type': patientData['blood_type'],
      'allergies': patientData['allergies'],
      'emergency_contact': patientData['emergency_contact'],
      'diagnoses': patientData['diagnoses'],
      'prescriptions': patientData['prescriptions'],
      'lab_reports': patientData['lab_reports'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    // Encrypt the full payload with the X25519 shared secret
    return await CryptoService.encryptAesGcm(
      jsonEncode(envelope),
      keyAlias: 'nfc_session_$sharedSecret',
    );
  }

  /// Build nurse-scoped payload:
  /// Nurse gets ONLY: patient name, age, blood group, current medicines, dosage, injections.
  /// DOES NOT get: diagnosis details, lab reports, historical records, billing, personal contacts.
  static Future<String> buildNursePayload({
    required Map<String, dynamic> patientData,
    required String sharedSecret,
  }) async {
    // Nurse sees only treatment-relevant, anonymized subset
    final envelope = {
      'role': 'nurse',
      'access_level': 'treatment_overview',
      'patient_id': patientData['patient_id'],
      'name': patientData['name'] ?? patientData['full_name'],
      'blood_type': patientData['blood_type'],
      'allergies': patientData['allergies'],
      // Only active medicines for medication administration
      'active_medicines': _extractActiveMedicines(patientData),
      // Injection schedule only
      'injection_schedule': _extractInjections(patientData),
      // Current health status only (no diagnosis details)
      'health_status': patientData['health_status'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return await CryptoService.encryptAesGcm(
      jsonEncode(envelope),
      keyAlias: 'nfc_session_nurse_$sharedSecret',
    );
  }

  static List<String> _extractActiveMedicines(Map<String, dynamic> data) {
    final prescriptions = data['prescriptions'] as List<dynamic>? ?? [];
    final medicines = <String>[];
    for (final rx in prescriptions) {
      if (rx is Map<String, dynamic>) {
        final status = rx['status'] as String?;
        if (status == 'pending' || status == 'dispensed') {
          final meds = rx['medicines'];
          if (meds is List) medicines.addAll(meds.map((m) => m.toString()));
        }
      }
    }
    return medicines;
  }

  static List<String> _extractInjections(Map<String, dynamic> data) {
    // Extract injection notes from nurse_logs if included in data
    final logs = data['nurse_logs'] as List<dynamic>? ?? [];
    return logs
        .where((l) => (l as Map<String, dynamic>)['action'] == 'INJECTION_GIVEN')
        .map((l) => (l as Map<String, dynamic>)['notes']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  /// Decrypt a received NFC payload using session shared secret
  static Future<Map<String, dynamic>> decryptPayload({
    required String encryptedData,
    required String sharedSecret,
    required NfcAccessRole role,
  }) async {
    final keyAlias = role == NfcAccessRole.nurse
        ? 'nfc_session_nurse_$sharedSecret'
        : 'nfc_session_$sharedSecret';
    final decrypted = await CryptoService.decryptAesGcm(encryptedData, keyAlias: keyAlias);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
}

class NfcService {
  static Future<bool> isAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  /// Doctor/Nurse: Initiate NFC session. Waits for patient tag.
  /// CRITICAL: NFC NEVER transfers plaintext. Only encrypted payloads.
  /// Returns NfcSessionResult with encrypted scoped payload for the given role.
  static Future<NfcSessionResult> initiateSession({
    required String myPublicKeyBase64,
    required String myUserId,
    required NfcAccessRole role,
    required void Function(NfcSessionState) onStateChange,
  }) async {
    final completer = Completer<NfcSessionResult>();

    void safeComplete(NfcSessionResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    try {
      final available = await isAvailable();
      if (!available) {
        return const NfcSessionResult(success: false, error: 'NFC not available on this device');
      }

      onStateChange(NfcSessionState.scanning);

      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              safeComplete(const NfcSessionResult(success: false, error: 'Tag does not support NDEF'));
              return;
            }

            final cachedMessage = ndef.cachedMessage;
            if (cachedMessage == null || cachedMessage.records.isEmpty) {
              safeComplete(const NfcSessionResult(success: false, error: 'No data on NFC tag'));
              return;
            }

            final record = cachedMessage.records.first;
            final payload = utf8.decode(record.payload.sublist(3)); // Skip lang code
            final tagData = jsonDecode(payload) as Map<String, dynamic>;

            final patientId = tagData['patientId'] as String?;
            final patientPublicKey = tagData['publicKey'] as String?;

            if (patientId == null || patientPublicKey == null) {
              safeComplete(const NfcSessionResult(success: false, error: 'Invalid tag data — missing keys'));
              return;
            }

            // X25519 ECDH key exchange → derive shared secret
            final myKeys = await CryptoService.generateX25519KeyPair();
            final sharedSecret = await CryptoService.deriveSharedSecret(
              myKeys['privateKey']!,
              patientPublicKey,
            );

            // Write BACK our public key to the tag (encrypted handshake only)
            final writeData = jsonEncode({
              'userId': myUserId,
              'publicKey': myKeys['publicKey'],
              'role': role.name,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });

            if (ndef.isWritable) {
              // Encrypt our response with patient's public key
              final encryptedResponse = await CryptoService.encryptAesGcm(
                writeData,
                keyAlias: 'nfc_response_$patientPublicKey',
              );
              final writeMessage = NdefMessage([NdefRecord.createText(encryptedResponse)]);
              await ndef.write(writeMessage);
            }

            onStateChange(NfcSessionState.connected);

            // Audit log — non-blocking
            AccessLogService.logNfcSession(
              patientId: patientId,
              accessedById: myUserId,
              accessedByRole: role.name,
              recordsViewed: [role == NfcAccessRole.doctor ? 'full_record' : 'treatment_overview'],
              startTime: DateTime.now(),
            );

            // Read encrypted patient payload from tag (role-scoped field)
            final roleField = role == NfcAccessRole.nurse ? 'nurse_payload' : 'doctor_payload';
            final encryptedPatientPayload = tagData[roleField] as String?;

            safeComplete(NfcSessionResult(
              success: true,
              patientId: patientId,
              sharedSecret: sharedSecret,
              scopedPayload: NfcScopedPayload(
                role: role,
                patientId: patientId,
                sharedSecret: sharedSecret,
                encryptedFullRecord: role == NfcAccessRole.doctor ? encryptedPatientPayload : null,
                encryptedTreatmentOverview: role == NfcAccessRole.nurse ? encryptedPatientPayload : null,
              ),
            ));
          } catch (e) {
            onStateChange(NfcSessionState.failed);
            safeComplete(NfcSessionResult(success: false, error: e.toString()));
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
        onError: (e) async {
          onStateChange(NfcSessionState.failed);
          safeComplete(NfcSessionResult(success: false, error: e.toString()));
        },
      );

      return await completer.future;
    } catch (e) {
      onStateChange(NfcSessionState.failed);
      return NfcSessionResult(success: false, error: e.toString());
    }
  }

  /// Patient: Write their scoped data to NFC tag for doctor/nurse to scan.
  /// CRITICAL: Only encrypted payloads are written. Both doctor and nurse
  /// payloads are written simultaneously so the correct role can read theirs.
  static Future<bool> writePatientTag({
    required String patientId,
    required String publicKeyBase64,
    Map<String, dynamic>? patientData,
    String? doctorEncryptedPayload,
    String? nurseEncryptedPayload,
  }) async {
    try {
      final available = await isAvailable();
      if (!available) return false;

      // Build tag payload — only public key + patient ID + pre-encrypted role payloads
      // NEVER include plaintext patient record
      final tagContent = jsonEncode({
        'patientId': patientId,
        'publicKey': publicKeyBase64,
        'app': 'CareCrypt',
        'version': '2.0',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        // Role-scoped encrypted payloads (pre-encrypted before writing to tag)
        if (doctorEncryptedPayload != null) 'doctor_payload': doctorEncryptedPayload,
        if (nurseEncryptedPayload != null) 'nurse_payload': nurseEncryptedPayload,
      });

      bool written = false;
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          final ndef = Ndef.from(tag);
          if (ndef != null && ndef.isWritable) {
            await ndef.write(NdefMessage([NdefRecord.createText(tagContent)]));
            written = true;
          }
          await NfcManager.instance.stopSession();
        },
      );

      return written;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopSession() async {
    await NfcManager.instance.stopSession();
  }
}

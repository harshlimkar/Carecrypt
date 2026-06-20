import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Logs NFC and QR access events to the `access_logs` table in Supabase.
/// Falls back gracefully if the table doesn't exist yet.
class AccessLogService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  // ──────────────────────────────────────────────────────
  // NFC Session Logging
  // ──────────────────────────────────────────────────────

  /// Log an NFC session after it completes.
  ///
  /// [patientId]      — Patient whose tag was scanned
  /// [accessedById]   — Doctor/Nurse user ID
  /// [accessedByRole] — 'doctor' | 'nurse'
  /// [recordsViewed]  — List of sections that were accessed
  /// [recordsModified]— List of sections that were written
  static Future<String?> logNfcSession({
    required String patientId,
    required String accessedById,
    required String accessedByRole,
    List<String> recordsViewed = const [],
    List<String> recordsModified = const [],
    DateTime? startTime,
  }) async {
    try {
      final sessionId = _uuid.v4();
      final now = DateTime.now();

      await _supabase.from('access_logs').insert({
        'id': sessionId,
        'accessor_id': accessedById,                         // OLD
        'patient_id': patientId,
        'action': 'NFC Session (${accessedByRole.toUpperCase()})', // OLD
        'is_honeypot': false,                                 // OLD
        'severity': 'INFO',                                    // OLD
        'timestamp': now.toIso8601String(),                   // OLD
        'access_type': 'nfc_session',                         // NEW
        'accessed_by': accessedById,                          // NEW
        'role': accessedByRole,                               // NEW
        'records_viewed': recordsViewed,
        'records_modified': recordsModified,
        'start_time': (startTime ?? now).toIso8601String(),
        'end_time': now.toIso8601String(),
        'status': 'completed',
        'metadata': {
          'session_id': sessionId,
          'app_version': '2.0',
        },
      });

      return sessionId;
    } catch (_) {
      // Non-critical — access log failure does not block the NFC flow
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  // QR Scan Logging
  // ──────────────────────────────────────────────────────

  /// Log a QR pharmacy scan event.
  ///
  /// [patientId]       — Patient ID from QR payload
  /// [pharmacistId]    — Pharmacist who scanned
  /// [prescriptionId]  — Prescription that was verified
  /// [medicinesDispensed] — List of medicines that were dispensed
  /// [qrStatus]        — 'dispensed' | 'expired' | 'already_used'
  static Future<String?> logQrScan({
    required String patientId,
    required String pharmacistId,
    required String prescriptionId,
    List<String> medicinesDispensed = const [],
    String qrStatus = 'dispensed',
  }) async {
    try {
      final logId = _uuid.v4();
      final now = DateTime.now();

      await _supabase.from('access_logs').insert({
        'id': logId,
        'accessor_id': pharmacistId,                          // OLD
        'patient_id': patientId,
        'action': 'QR Scan ($qrStatus)',                      // OLD
        'is_honeypot': false,                                 // OLD
        'severity': qrStatus == 'dispensed' ? 'INFO' : 'WARNING', // OLD
        'timestamp': now.toIso8601String(),                   // OLD
        'access_type': 'qr_scan',                             // NEW
        'accessed_by': pharmacistId,                          // NEW
        'role': 'pharmacy',                                   // NEW
        'records_viewed': ['prescription', 'medicines'],
        'records_modified': qrStatus == 'dispensed' ? ['prescription_status'] : [],
        'start_time': now.toIso8601String(),
        'end_time': now.toIso8601String(),
        'status': qrStatus,
        'metadata': {
          'log_id': logId,
          'prescription_id': prescriptionId,
          'medicines_dispensed': medicinesDispensed,
          'qr_status': qrStatus,
        },
      });

      return logId;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  // Report Data (for display in audit UI)
  // ──────────────────────────────────────────────────────

  /// Fetch recent access logs for a patient.
  static Future<List<Map<String, dynamic>>> fetchPatientLogs(
    String patientId, {int limit = 20}
  ) async {
    try {
      final result = await _supabase
          .from('access_logs')
          .select('*')
          .eq('patient_id', patientId)
          .order('end_time', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(result as List);
    } catch (_) {
      return [];
    }
  }
}

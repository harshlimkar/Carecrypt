import 'package:supabase_flutter/supabase_flutter.dart';

class HoneypatientGuard {
  static const _honeypatientIds = [
    'PAT-HONEYPOT-001',
    'PAT-HONEYPOT-002',
    'PAT-HONEYPOT-003',
  ];

  static bool isHoneypatient(String patientId) {
    return _honeypatientIds.contains(patientId.toUpperCase());
  }

  static Future<void> triggerAlert({
    required String accessorId,
    required String accessorRole,
    required String patientId,
    required String action,
    String? ipAddress,
  }) async {
    final supabase = Supabase.instance.client;

    // Log the incident to access_logs with HONEYPOT flag
    await supabase.from('access_logs').insert({
      'accessor_id': accessorId,
      'patient_id': patientId,
      'action': action,
      'ip_address': ipAddress ?? 'unknown',
      'is_honeypot': true,
      'severity': 'CRITICAL',
      'metadata': {
        'accessor_role': accessorRole,
        'honeypatient_id': patientId,
        'alert_type': 'UNAUTHORIZED_HONEYPOT_ACCESS',
      },
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Send security alert notification to all admins
    await supabase.rpc('notify_security_admins', params: {
      'alert_type': 'HONEYPOT_ACCESS',
      'accessor_id': accessorId,
      'patient_id': patientId,
      'severity': 'CRITICAL',
      'message':
          '🚨 SECURITY BREACH: User $accessorId ($accessorRole) attempted to access honeypot record $patientId',
    });
  }

  /// Guard a patient query — call this before any patient data access
  static Future<GuardResult> guard({
    required String patientId,
    required String accessorId,
    required String accessorRole,
    required String action,
  }) async {
    // Log ALL access (including legitimate ones)
    await _logAccess(
      accessorId: accessorId,
      patientId: patientId,
      action: action,
      isHoneypot: false,
    );

    if (isHoneypatient(patientId)) {
      await triggerAlert(
        accessorId: accessorId,
        accessorRole: accessorRole,
        patientId: patientId,
        action: action,
      );
      return GuardResult.denied(
        reason: 'Access denied', // Vague response to avoid fingerprinting
      );
    }

    return GuardResult.allowed();
  }

  static Future<void> _logAccess({
    required String accessorId,
    required String patientId,
    required String action,
    required bool isHoneypot,
  }) async {
    try {
      await Supabase.instance.client.from('access_logs').insert({
        'accessor_id': accessorId,
        'patient_id': patientId,
        'action': action,
        'is_honeypot': isHoneypot,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Never block on audit logging failure
    }
  }
}

class GuardResult {
  final bool allowed;
  final String? reason;

  const GuardResult._({required this.allowed, this.reason});

  factory GuardResult.allowed() => const GuardResult._(allowed: true);
  factory GuardResult.denied({required String reason}) =>
      GuardResult._(allowed: false, reason: reason);
}

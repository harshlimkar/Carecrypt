// Patient domain data models for CareCrypt

class PatientProfile {
  final String patientId;
  final String name;
  final String dateOfBirth;
  final String gender;
  final String bloodType;
  final String? allergies;
  final String? emergencyContact;
  final String? avatarUrl;

  const PatientProfile({
    required this.patientId,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodType,
    this.allergies,
    this.emergencyContact,
    this.avatarUrl,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    patientId: json['patient_id'] as String? ?? '',
    name: json['name'] as String? ?? json['full_name'] as String? ?? 'Unknown',
    dateOfBirth: json['date_of_birth'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    bloodType: json['blood_type'] as String? ?? '',
    allergies: json['allergies'] as String?,
    emergencyContact: json['emergency_contact'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class HealthMetrics {
  final int heartRate;
  final String bloodPressure;
  final double bloodGlucose;
  final String healthStatus;

  const HealthMetrics({
    required this.heartRate,
    required this.bloodPressure,
    required this.bloodGlucose,
    required this.healthStatus,
  });

  factory HealthMetrics.fromJson(Map<String, dynamic> json) => HealthMetrics(
    heartRate: (json['heart_rate'] as num?)?.toInt() ?? 72,
    bloodPressure: json['blood_pressure'] as String? ?? '120/80',
    bloodGlucose: (json['blood_glucose'] as num?)?.toDouble() ?? 96.0,
    healthStatus: json['health_status'] as String? ?? 'Stable',
  );
}

class Diagnosis {
  final String id;
  final String patientId;
  final String doctorId;
  final String diagnosis;
  final String? notes;
  final String status;
  final DateTime createdAt;

  const Diagnosis({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.diagnosis,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory Diagnosis.fromJson(Map<String, dynamic> json) => Diagnosis(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    doctorId: json['doctor_id'] as String? ?? '',
    diagnosis: json['diagnosis'] as String? ?? json['encrypted_diagnosis'] as String? ?? '',
    notes: json['notes'] as String?,
    status: json['status'] as String? ?? 'active',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final List<String> medicines;
  final String? instructions;
  final String status;
  final String? signature;
  final DateTime createdAt;

  const Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.medicines,
    this.instructions,
    required this.status,
    this.signature,
    required this.createdAt,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final medicinesRaw = json['medicines'];
    List<String> medicines = [];
    if (medicinesRaw is List) {
      medicines = medicinesRaw.map((m) => m.toString()).toList();
    } else if (medicinesRaw is String) {
      medicines = [medicinesRaw];
    }
    return Prescription(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String? ?? '',
      medicines: medicines,
      instructions: json['instructions'] as String?,
      status: json['status'] as String? ?? 'pending',
      signature: json['ed25519_signature'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class LabReport {
  final String id;
  final String requestId;
  final String? stegoImageUrl;
  final String? sha256Hash;
  final bool verified;
  final DateTime createdAt;

  const LabReport({
    required this.id,
    required this.requestId,
    this.stegoImageUrl,
    this.sha256Hash,
    required this.verified,
    required this.createdAt,
  });

  factory LabReport.fromJson(Map<String, dynamic> json) => LabReport(
    id: json['id'] as String,
    requestId: json['request_id'] as String? ?? '',
    stegoImageUrl: json['stego_image_url'] as String?,
    sha256Hash: json['sha256_hash'] as String?,
    verified: json['verified'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class NurseLog {
  final String id;
  final String patientId;
  final String nurseId;
  final String action;
  final String? notes;
  final DateTime timestamp;

  const NurseLog({
    required this.id,
    required this.patientId,
    required this.nurseId,
    required this.action,
    this.notes,
    required this.timestamp,
  });

  factory NurseLog.fromJson(Map<String, dynamic> json) => NurseLog(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    nurseId: json['nurse_id'] as String? ?? '',
    action: json['action'] as String? ?? '',
    notes: json['notes'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class AccessLog {
  final String id;
  final String accessorId;
  final String patientId;
  final String action;
  final bool isHoneypot;
  final DateTime timestamp;

  const AccessLog({
    required this.id,
    required this.accessorId,
    required this.patientId,
    required this.action,
    required this.isHoneypot,
    required this.timestamp,
  });

  factory AccessLog.fromJson(Map<String, dynamic> json) => AccessLog(
    id: json['id'] as String,
    accessorId: json['accessor_id'] as String? ?? '',
    patientId: json['patient_id'] as String? ?? '',
    action: json['action'] as String? ?? '',
    isHoneypot: json['is_honeypot'] as bool? ?? false,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String message;
  final bool read;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.read,
    this.metadata,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    type: json['type'] as String? ?? 'info',
    message: json['message'] as String? ?? '',
    read: json['read'] as bool? ?? false,
    metadata: json['metadata'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class LabRequest {
  final String id;
  final String patientId;
  final String doctorId;
  final String testType;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const LabRequest({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.testType,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory LabRequest.fromJson(Map<String, dynamic> json) => LabRequest(
    id: json['id'] as String,
    patientId: json['patient_id'] as String? ?? '',
    doctorId: json['doctor_id'] as String? ?? '',
    testType: json['test_type'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

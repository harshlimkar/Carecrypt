class CareCryptUser {
  final String id;
  final String email;
  final String role;
  final String displayName;
  final String? patientId;
  final String? publicKey;
  final String? avatarUrl;
  final DateTime createdAt;

  const CareCryptUser({
    required this.id,
    required this.email,
    required this.role,
    required this.displayName,
    this.patientId,
    this.publicKey,
    this.avatarUrl,
    required this.createdAt,
  });

  factory CareCryptUser.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? patientData;
    if (json['patients'] is List) {
      final list = json['patients'] as List;
      if (list.isNotEmpty) {
        patientData = list.first as Map<String, dynamic>?;
      }
    } else if (json['patients'] is Map) {
      patientData = json['patients'] as Map<String, dynamic>?;
    }

    return CareCryptUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      displayName: json['display_name'] as String? ?? json['email'] as String,
      patientId: patientData?['patient_id'] as String?,
      publicKey: json['public_key'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName.substring(0, 2).toUpperCase();
  }

  String get roleDisplay => switch (role) {
    'patient' => 'Patient',
    'doctor' => 'Doctor',
    'lab' => 'Lab Technician',
    'pharmacist' => 'Pharmacist',
    'nurse' => 'Nurse',
    _ => role,
  };

  String get dashboardRoute => switch (role) {
    'patient' => '/patient/dashboard',
    'doctor' => '/doctor/dashboard',
    'lab' => '/lab/dashboard',
    'pharmacist' => '/pharmacy/scanner',
    'nurse' => '/nurse/nfc',
    _ => '/login',
  };
}

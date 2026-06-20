class AppRoutes {
  static const splash = '/';
  static const login = '/login';

  // Patient routes
  static const patientDashboard = '/patient/dashboard';
  static const patientRecords = '/patient/records';
  static const patientQr = '/patient/qr';
  static const patientNotifications = '/patient/notifications';
  static const patientAccessLog = '/patient/access-log';

  // Doctor routes
  static const doctorDashboard = '/doctor/dashboard';
  static const doctorPatientAccess = '/doctor/patient-access';
  static const doctorLabRequest = '/doctor/lab-request';
  static const doctorPrescription = '/doctor/prescription';

  // Lab routes
  static const labDashboard = '/lab/dashboard';
  static const labUploadReport = '/lab/upload-report';

  // Pharmacy routes
  static const pharmacyScanner = '/pharmacy/scanner';
  static const pharmacyPrescriptionDetail = '/pharmacy/prescription';

  // Nurse routes
  static const nurseNfc = '/nurse/nfc';
  static const nurseTreatment = '/nurse/treatment';
}

class AppRoles {
  static const patient = 'patient';
  static const doctor = 'doctor';
  static const lab = 'lab';
  static const pharmacist = 'pharmacist';
  static const nurse = 'nurse';
}

class AppStrings {
  static const appName = 'CareCrypt';
  static const tagline = 'Your Health. Your Data. Your Control.';
  static const encryptionBadge = 'AES-256 Encrypted';
  static const systemNominal = 'System Nominal';
  static const serverNode = 'SRV-772_NODE';
  static const trustCenter = 'Trust Center';
  static const secureAccess = 'Secure Access';
  static const biometricFailed = 'Biometric authentication failed';
  static const nfcNotSupported = 'NFC not supported on this device';
  static const honeypatientAlert = 'SECURITY ALERT: Unauthorized access attempt detected';
}

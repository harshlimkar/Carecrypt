import 'dart:convert';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/crypto_service.dart';
import '../../../core/services/stego_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/access_log_service.dart';

// ────────────────────────────────────────────────────────
// LAB BLoC
// ────────────────────────────────────────────────────────

abstract class LabEvent extends Equatable {
  const LabEvent();
  @override List<Object?> get props => [];
}

class LabLoadDashboard extends LabEvent {
  final String labId;
  const LabLoadDashboard({required this.labId});
  @override List<Object?> get props => [labId];
}

class LabUploadReport extends LabEvent {
  final String requestId;
  final String patientId;
  final String labId;
  final Uint8List reportBytes;
  final String encryptionKeyAlias;
  final String testResult;
  final String observation;
  final String remarks;
  // Metadata for the PDF
  final String testType;
  final String technicianName;
  const LabUploadReport({
    required this.requestId,
    required this.patientId,
    required this.labId,
    required this.reportBytes,
    required this.encryptionKeyAlias,
    this.testResult = '',
    this.observation = '',
    this.remarks = '',
    this.testType = '',
    this.technicianName = '',
  });
  @override List<Object?> get props => [requestId];
}

class LabDownloadReport extends LabEvent {
  final String requestId;
  final String patientId;
  final String keyAlias;
  const LabDownloadReport({
    required this.requestId,
    required this.patientId,
    required this.keyAlias,
  });
  @override List<Object?> get props => [requestId];
}

abstract class LabState extends Equatable {
  const LabState();
  @override List<Object?> get props => [];
}

class LabInitial extends LabState {}
class LabLoading extends LabState {}

class LabDashboardLoaded extends LabState {
  final List<Map<String, dynamic>> pendingApprovalRequests;
  final List<Map<String, dynamic>> approvedRequests;
  final List<Map<String, dynamic>> completedRequests;
  const LabDashboardLoaded({
    required this.pendingApprovalRequests,
    required this.approvedRequests,
    required this.completedRequests,
  });
  @override List<Object?> get props => [approvedRequests];
}

class LabReportUploading extends LabState {
  final String step;
  final ReportUploadStatus reportStatus;
  const LabReportUploading({required this.step, this.reportStatus = ReportUploadStatus.draft});
  @override List<Object?> get props => [step];
}

class LabReportUploaded extends LabState {
  final String message;
  const LabReportUploaded({required this.message});
  @override List<Object?> get props => [message];
}

class LabError extends LabState {
  final String message;
  const LabError({required this.message});
  @override List<Object?> get props => [message];
}

class LabReportReady extends LabState {
  final Uint8List pdfBytes;
  final String requestId;
  const LabReportReady({required this.pdfBytes, required this.requestId});
  @override List<Object?> get props => [requestId];
}

enum ReportUploadStatus { draft, encrypted, uploaded }

class LabBloc extends Bloc<LabEvent, LabState> {
  final _supabase = Supabase.instance.client;

  LabBloc() : super(LabInitial()) {
    on<LabLoadDashboard>(_onLoadDashboard);
    on<LabUploadReport>(_onUploadReport);
    on<LabDownloadReport>(_onDownloadReport);
  }

  Future<void> _onLoadDashboard(LabLoadDashboard event, Emitter<LabState> emit) async {
    emit(LabLoading());
    try {
      // Fetch lab_requests WITHOUT embedded join (no FK relationship exists)
      final results = await Future.wait([
        // Pending patient approval
        _supabase.from('lab_requests')
            .select('id, patient_id, test_type, urgency, notes, status, created_at')
            .eq('lab_id', event.labId)
            .eq('status', 'pending')
            .order('created_at', ascending: false),
        // Patient approved → lab can now act
        _supabase.from('lab_requests')
            .select('id, patient_id, test_type, urgency, notes, status, created_at')
            .eq('lab_id', event.labId)
            .eq('status', 'approved')
            .order('created_at', ascending: false),
        // Completed tests archive
        _supabase.from('lab_requests')
            .select('id, patient_id, test_type, urgency, notes, status, created_at')
            .eq('lab_id', event.labId)
            .eq('status', 'completed')
            .order('created_at', ascending: false)
            .limit(20),
      ]);

      final pending  = List<Map<String, dynamic>>.from(results[0] as List);
      final approved = List<Map<String, dynamic>>.from(results[1] as List);
      final completed = List<Map<String, dynamic>>.from(results[2] as List);

      // Collect all unique patient_ids to batch-fetch patient names
      final allRequests = [...pending, ...approved, ...completed];
      final patientIds = allRequests
          .map((r) => r['patient_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // Build a patient name lookup map (single query, not N+1)
      final Map<String, String> patientNameMap = {};
      if (patientIds.isNotEmpty) {
        try {
          final patientRows = await _supabase
              .from('patients')
              .select('patient_id, name')
              .inFilter('patient_id', patientIds);
          for (final row in patientRows as List) {
            final pid  = row['patient_id'] as String?;
            final name = row['name'] as String?;
            if (pid != null) patientNameMap[pid] = name ?? pid;
          }
        } catch (_) {
          // Non-critical — cards will just show patient_id if lookup fails
        }
      }

      // Merge patient name into each request as a synthetic 'patients' map
      List<Map<String, dynamic>> enrich(List<Map<String, dynamic>> list) =>
          list.map((r) {
            final pid = r['patient_id'] as String? ?? '';
            return {
              ...r,
              'patients': {
                'patient_id': pid,
                'name': patientNameMap[pid] ?? pid,
              },
            };
          }).toList();

      emit(LabDashboardLoaded(
        pendingApprovalRequests: enrich(pending),
        approvedRequests: enrich(approved),
        completedRequests: enrich(completed),
      ));
    } catch (e) {
      emit(LabError(message: e.toString()));
    }
  }

  Future<void> _onUploadReport(LabUploadReport event, Emitter<LabState> emit) async {
    try {
      // Step 1: Build report JSON with structured fields
      emit(const LabReportUploading(step: 'Preparing report data...', reportStatus: ReportUploadStatus.draft));
      final reportData = {
        'test_result': event.testResult,
        'observation': event.observation,
        'remarks': event.remarks,
        'lab_id': event.labId,
        'request_id': event.requestId,
        'patient_id': event.patientId,
        'test_name': event.testType,
        'test_type': event.testType,
        'technician_name': event.technicianName,
        'generated_at': DateTime.now().toIso8601String(),
      };
      final reportJson = jsonEncode(reportData);

      // Step 2: AES-256-GCM Encrypt
      emit(const LabReportUploading(step: 'Encrypting report (AES-256-GCM)...', reportStatus: ReportUploadStatus.draft));
      final sourceBytes = event.reportBytes.isNotEmpty
          ? event.reportBytes
          : Uint8List.fromList(reportJson.codeUnits);
      final reportBase64 = base64Encode(sourceBytes);
      final encryptedJson = await CryptoService.encryptAesGcm(reportBase64, keyAlias: event.encryptionKeyAlias);

      // Step 3: SHA-256 hash
      emit(const LabReportUploading(step: 'Computing SHA-256 integrity hash...', reportStatus: ReportUploadStatus.encrypted));
      final hash = await CryptoService.sha256Hash(Uint8List.fromList(encryptedJson.codeUnits));

      // Step 4: LSB Steganography — embed encrypted data in synthetic image
      emit(const LabReportUploading(step: 'Applying steganography...', reportStatus: ReportUploadStatus.encrypted));
      final encryptedBytes = Uint8List.fromList(encryptedJson.codeUnits);
      final stegoImage = StegoService.hideDataAuto(encryptedBytes);
      final stegoBase64 = base64Encode(stegoImage);

      // Step 5: Store encrypted content as text in PostgreSQL (no Storage bucket needed)
      emit(const LabReportUploading(step: 'Saving encrypted report...', reportStatus: ReportUploadStatus.encrypted));
      await _supabase.from('lab_reports').insert({
        'request_id': event.requestId,
        'patient_id': event.patientId,
        'encrypted_content': encryptedJson,       // AES-GCM JSON text
        'stego_image_b64': stegoBase64,            // Stego image as base64 text
        'sha256_hash': hash,
        'encrypted_by': event.labId,
        'key_alias': event.encryptionKeyAlias,
        'report_metadata': jsonEncode(reportData), // Unencrypted metadata for display
        'verified': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Step 6: Update request status
      emit(const LabReportUploading(step: 'Finalizing...', reportStatus: ReportUploadStatus.uploaded));
      await _supabase.from('lab_requests').update({'status': 'completed'}).eq('id', event.requestId);

      // Step 7: Notify patient and doctor
      try {
        await _supabase.rpc('notify_user_by_patient_id', params: {
          'p_patient_id': event.patientId,
          'p_type': 'report_uploaded',
          'p_message': 'Your lab report is ready. Encrypted and secured with AES-256-GCM.',
          'p_metadata': {'request_id': event.requestId},
        });
      } catch (_) {
        // Non-critical: notification failure doesn't block upload success
      }

      emit(const LabReportUploaded(message: 'Report encrypted, steganographed, and saved securely!'));
    } catch (e) {
      emit(LabError(message: e.toString()));
    }
  }

  Future<void> _onDownloadReport(LabDownloadReport event, Emitter<LabState> emit) async {
    emit(LabLoading());
    try {
      // Fetch encrypted report from PostgreSQL
      final row = await _supabase
          .from('lab_reports')
          .select('encrypted_content, sha256_hash, key_alias, report_metadata, encrypted_by, created_at')
          .eq('request_id', event.requestId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      final encryptedContent = row['encrypted_content'] as String;
      final hash = row['sha256_hash'] as String? ?? '';
      final keyAlias = (row['key_alias'] as String?)?.isNotEmpty == true
          ? row['key_alias'] as String
          : event.keyAlias;
      final metadataJson = row['report_metadata'] as String? ?? '{}';

      // Decrypt (validates the key is still valid; PDF uses metadata)
      // ignore: unused_local_variable
      final decryptedBase64Validation = await CryptoService.decryptAesGcm(encryptedContent, keyAlias: keyAlias);

      // Parse metadata for PDF
      Map<String, dynamic> reportMeta = {};
      try { reportMeta = jsonDecode(metadataJson) as Map<String, dynamic>; } catch (_) {}

      // Fetch patient info
      try {
        final patient = await _supabase
            .from('patients')
            .select('name, date_of_birth, gender, blood_type')
            .eq('patient_id', event.patientId)
            .maybeSingle();
        if (patient != null) {
          reportMeta['patient_name'] = patient['name'];
          reportMeta['gender'] = patient['gender'];
          reportMeta['blood_type'] = patient['blood_type'];
        }
      } catch (_) {}

      reportMeta['patient_id'] = event.patientId;
      reportMeta['sha256_hash'] = hash;

      // Generate professional PDF
      final pdfBytes = await PdfService.generateLabReport(reportMeta);
      emit(LabReportReady(pdfBytes: pdfBytes, requestId: event.requestId));
    } catch (e) {
      emit(LabError(message: 'Failed to load report: ${e.toString()}'));
    }
  }
}

// ────────────────────────────────────────────────────────
// PHARMACY BLoC
// ────────────────────────────────────────────────────────

abstract class PharmacyEvent extends Equatable {
  const PharmacyEvent();
  @override List<Object?> get props => [];
}

class PharmacyScanQr extends PharmacyEvent {
  final String qrPayload;
  final String pharmacistId;
  const PharmacyScanQr({required this.qrPayload, required this.pharmacistId});
  @override List<Object?> get props => [qrPayload];
}

class PharmacyDispenseMedicine extends PharmacyEvent {
  final String prescriptionId;
  final String pharmacistId;
  final String patientId;
  final List<String> medicines;
  const PharmacyDispenseMedicine({
    required this.prescriptionId,
    required this.pharmacistId,
    this.patientId = '',
    this.medicines = const [],
  });

  @override List<Object?> get props => [prescriptionId];
}

abstract class PharmacyState extends Equatable {
  const PharmacyState();
  @override List<Object?> get props => [];
}

class PharmacyInitial extends PharmacyState {}
class PharmacyLoading extends PharmacyState {}
class PharmacyPrescriptionVerified extends PharmacyState {
  final Map<String, dynamic> prescription;
  final bool signatureValid;
  const PharmacyPrescriptionVerified({required this.prescription, required this.signatureValid});
  @override List<Object?> get props => [prescription];
}
class PharmacyDispenseSuccess extends PharmacyState {}
class PharmacyQrAlreadyUsed extends PharmacyState {
  final String message;
  const PharmacyQrAlreadyUsed({required this.message});
  @override List<Object?> get props => [message];
}
class PharmacyQrExpired extends PharmacyState {
  final String message;
  const PharmacyQrExpired({required this.message});
  @override List<Object?> get props => [message];
}
class PharmacyError extends PharmacyState {
  final String message;
  const PharmacyError({required this.message});
  @override List<Object?> get props => [message];
}

class PharmacyBloc extends Bloc<PharmacyEvent, PharmacyState> {
  final _supabase = Supabase.instance.client;

  PharmacyBloc() : super(PharmacyInitial()) {
    on<PharmacyScanQr>(_onScanQr);
    on<PharmacyDispenseMedicine>(_onDispense);
  }

  Future<void> _onScanQr(PharmacyScanQr event, Emitter<PharmacyState> emit) async {
    emit(PharmacyLoading());
    try {
      // ── Step 1: Parse outer QR envelope ──────────────────────────────────
      final Map<String, dynamic> qrMap;
      try {
        qrMap = jsonDecode(event.qrPayload) as Map<String, dynamic>;
      } catch (_) {
        emit(const PharmacyError(message: 'Invalid QR code: not a CareCrypt QR code.'));
        return;
      }

      // NULL-GUARD: ensure 'data' field exists (prevents the Null→String crash)
      final encryptedData = qrMap['data'];
      if (encryptedData == null || encryptedData is! String || encryptedData.isEmpty) {
        emit(const PharmacyError(message: 'Invalid QR code: missing encrypted payload. Please ask the patient to regenerate the QR.'));
        return;
      }

      final signature = qrMap['sig'] as String?;

      // ── Step 2: Decrypt using embedded key (AES-256-GCM) ─────────────────
      // No keyAlias → reads the ephemeral key embedded inside the ciphertext JSON
      // (same pattern as harshlimkar/crypto: key is packaged with ciphertext)
      final decrypted = await CryptoService.decryptAesGcm(encryptedData);
      final payload = jsonDecode(decrypted) as Map<String, dynamic>;

      // CLIENT-SIDE: Check expiry first (fast reject)
      final expiry = payload['expiry'] as int?;
      if (expiry != null && DateTime.fromMillisecondsSinceEpoch(expiry).isBefore(DateTime.now())) {
        emit(const PharmacyQrExpired(message: 'QR Expired — Please ask the patient to generate a new QR code.'));
        return;
      }

      // SERVER-SIDE: Atomic one-time token invalidation
      final tokenId = payload['token_id'] as String?;
      if (tokenId != null) {
        try {
          final tokenResult = await _supabase.rpc('use_qr_token', params: {'p_token_id': tokenId});
          final resultData = tokenResult as Map<String, dynamic>?;
          if (resultData != null && resultData['success'] == false) {
            final error = resultData['error'] as String? ?? 'QR validation failed';
            if (error.contains('Already Used')) {
              emit(PharmacyQrAlreadyUsed(message: error));
            } else {
              emit(PharmacyQrExpired(message: error));
            }
            return;
          }
        } catch (_) {
          // If RPC doesn't exist yet (migration not run), fall through gracefully
        }
      }

      // Fetch prescription from DB
      final prescriptionId = payload['prescription_id'] as String?;
      Map<String, dynamic> prescription;
      if (prescriptionId != null) {
        final fallbackMap = Map<String, dynamic>.from(payload);
        fallbackMap['id'] = prescriptionId;
        try {
          final rxData = await _supabase.from('prescriptions').select('*').eq('id', prescriptionId).single();
          prescription = rxData;
        } catch (_) {
          prescription = fallbackMap;
        }
      } else {
        prescription = Map<String, dynamic>.from(payload);
      }

      // Verify Ed25519 signature
      bool signatureValid = false;
      if (signature != null) {
        try {
          final userData = await _supabase
              .from('users')
              .select('public_key')
              .eq('id', payload['user_id'] as String? ?? '')
              .maybeSingle();
          final publicKey = userData?['public_key'] as String?;
          if (publicKey != null) {
            signatureValid = await CryptoService.verifyEd25519(encryptedData, signature, publicKey);
          }
        } catch (_) {
          // Signature check non-blocking
        }
      }

      emit(PharmacyPrescriptionVerified(prescription: prescription, signatureValid: signatureValid));
    } catch (e) {
      emit(PharmacyError(message: 'Invalid QR code: ${e.toString()}'));
    }
  }

  Future<void> _onDispense(PharmacyDispenseMedicine event, Emitter<PharmacyState> emit) async {
    try {
      await _supabase.from('prescriptions').update({'status': 'dispensed'}).eq('id', event.prescriptionId);
      await _supabase.from('medicine_status').insert({
        'prescription_id': event.prescriptionId,
        'status': 'dispensed',
        'dispensed_at': DateTime.now().toIso8601String(),
        'pharmacist_id': event.pharmacistId,
      });

      // Log QR scan audit trail
      AccessLogService.logQrScan(
        patientId: event.patientId,
        pharmacistId: event.pharmacistId,
        prescriptionId: event.prescriptionId,
        medicinesDispensed: event.medicines,
        qrStatus: 'dispensed',
      );

      emit(PharmacyDispenseSuccess());

    } catch (e) {
      emit(PharmacyError(message: e.toString()));
    }
  }
}

// ────────────────────────────────────────────────────────
// NURSE BLoC
// ────────────────────────────────────────────────────────
abstract class NurseEvent extends Equatable {
  const NurseEvent();
  @override List<Object?> get props => [];
}

class NurseLoadTreatment extends NurseEvent {
  final String patientId;
  final String nurseId;
  const NurseLoadTreatment({required this.patientId, required this.nurseId});
  @override List<Object?> get props => [patientId, nurseId];
}

class NurseUpdateMedicine extends NurseEvent {
  final String patientId;
  final String nurseId;
  final String medicine;
  final String notes;
  const NurseUpdateMedicine({required this.patientId, required this.nurseId, required this.medicine, this.notes = ''});
  @override List<Object?> get props => [patientId, medicine];
}

class NurseUpdateInjection extends NurseEvent {
  final String patientId;
  final String nurseId;
  final String injection;
  const NurseUpdateInjection({required this.patientId, required this.nurseId, required this.injection});
  @override List<Object?> get props => [patientId, injection];
}

abstract class NurseState extends Equatable {
  const NurseState();
  @override List<Object?> get props => [];
}

class NurseInitial extends NurseState {}
class NurseLoading extends NurseState {}
class NurseTreatmentLoaded extends NurseState {
  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> diagnoses;
  final List<Map<String, dynamic>> prescriptions;
  const NurseTreatmentLoaded({required this.patient, required this.diagnoses, required this.prescriptions});
  @override List<Object?> get props => [patient];
}
class NurseActionSuccess extends NurseState {
  final String message;
  const NurseActionSuccess({required this.message});
  @override List<Object?> get props => [message];
}
class NurseError extends NurseState {
  final String message;
  const NurseError({required this.message});
  @override List<Object?> get props => [message];
}

class NurseBloc extends Bloc<NurseEvent, NurseState> {
  final _supabase = Supabase.instance.client;

  NurseBloc() : super(NurseInitial()) {
    on<NurseLoadTreatment>(_onLoadTreatment);
    on<NurseUpdateMedicine>(_onUpdateMedicine);
    on<NurseUpdateInjection>(_onUpdateInjection);
  }

  Future<void> _onLoadTreatment(NurseLoadTreatment event, Emitter<NurseState> emit) async {
    emit(NurseLoading());
    try {
      final results = await Future.wait([
        // Nurse only gets limited patient fields (no full history)
        _supabase.from('patients')
            .select('patient_id, name, full_name, date_of_birth, gender, blood_type, allergies, health_status')
            .eq('patient_id', event.patientId)
            .single(),
        // Only current/active diagnoses summary
        _supabase.from('diagnosis')
            .select('diagnosis, status, notes')
            .eq('patient_id', event.patientId)
            .inFilter('status', ['active', 'chronic'])
            .order('created_at', ascending: false)
            .limit(5),
        // Only pending prescriptions (current medicines)
        _supabase.from('prescriptions')
            .select('medicines, instructions, status')
            .eq('patient_id', event.patientId)
            .inFilter('status', ['pending', 'dispensed'])
            .order('created_at', ascending: false)
            .limit(5),
      ]);
      emit(NurseTreatmentLoaded(
        patient: results[0] as Map<String, dynamic>,
        diagnoses: List<Map<String, dynamic>>.from(results[1] as List),
        prescriptions: List<Map<String, dynamic>>.from(results[2] as List),
      ));
    } catch (e) {
      emit(NurseError(message: e.toString()));
    }
  }

  Future<void> _onUpdateMedicine(NurseUpdateMedicine event, Emitter<NurseState> emit) async {
    try {
      await _supabase.from('nurse_logs').insert({
        'patient_id': event.patientId,
        'nurse_id': event.nurseId,
        'action': 'MEDICINE_GIVEN',
        'notes': '${event.medicine}${event.notes.isNotEmpty ? ': ${event.notes}' : ''}',
        'timestamp': DateTime.now().toIso8601String(),
      });
      emit(const NurseActionSuccess(message: 'Medicine administration logged'));
    } catch (e) {
      emit(NurseError(message: e.toString()));
    }
  }

  Future<void> _onUpdateInjection(NurseUpdateInjection event, Emitter<NurseState> emit) async {
    try {
      await _supabase.from('nurse_logs').insert({
        'patient_id': event.patientId,
        'nurse_id': event.nurseId,
        'action': 'INJECTION_GIVEN',
        'notes': event.injection,
        'timestamp': DateTime.now().toIso8601String(),
      });
      emit(const NurseActionSuccess(message: 'Injection logged successfully'));
    } catch (e) {
      emit(NurseError(message: e.toString()));
    }
  }
}

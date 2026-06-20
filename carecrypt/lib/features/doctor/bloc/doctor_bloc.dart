import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/security/honeypatient_guard.dart';

// ─── Events ───
abstract class DoctorEvent extends Equatable {
  const DoctorEvent();
  @override List<Object?> get props => [];
}

class DoctorLoadDashboard extends DoctorEvent {
  final String doctorId;
  const DoctorLoadDashboard({required this.doctorId});
  @override List<Object?> get props => [doctorId];
}

class DoctorLoadPatient extends DoctorEvent {
  final String patientId;
  final String doctorId;
  const DoctorLoadPatient({required this.patientId, required this.doctorId});
  @override List<Object?> get props => [patientId, doctorId];
}

class DoctorCreateLabRequest extends DoctorEvent {
  final String patientId;
  final String doctorId;
  final String testType;
  final String? notes;
  final String urgency;
  const DoctorCreateLabRequest({required this.patientId, required this.doctorId, required this.testType, this.notes, required this.urgency});
  @override List<Object?> get props => [patientId, doctorId, testType];
}

class DoctorCreatePrescription extends DoctorEvent {
  final String patientId;
  final String doctorId;
  final List<String> medicines;
  final String? instructions;
  final String privateKeyBase64;
  const DoctorCreatePrescription({required this.patientId, required this.doctorId, required this.medicines, this.instructions, required this.privateKeyBase64});
  @override List<Object?> get props => [patientId, medicines];
}

class DoctorAnalyzePrescription extends DoctorEvent {
  final List<String> medicines;
  final List<String> diagnoses;
  final List<String> history;
  const DoctorAnalyzePrescription({required this.medicines, required this.diagnoses, required this.history});
  @override List<Object?> get props => [medicines];
}

class DoctorCreateDiagnosis extends DoctorEvent {
  final String patientId;
  final String doctorId;
  final String diagnosis;
  final String? notes;
  const DoctorCreateDiagnosis({required this.patientId, required this.doctorId, required this.diagnosis, this.notes});
  @override List<Object?> get props => [patientId, diagnosis];
}

// ─── States ───
abstract class DoctorState extends Equatable {
  const DoctorState();
  @override List<Object?> get props => [];
}

class DoctorInitial extends DoctorState {}
class DoctorLoading extends DoctorState {}

class DoctorDashboardLoaded extends DoctorState {
  final List<Map<String, dynamic>> recentPatients;
  final List<Map<String, dynamic>> recentDiagnoses;
  const DoctorDashboardLoaded({required this.recentPatients, required this.recentDiagnoses});
  @override List<Object?> get props => [recentPatients];
}

class DoctorPatientLoaded extends DoctorState {
  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> diagnoses;
  final List<Map<String, dynamic>> prescriptions;
  final List<Map<String, dynamic>> labReports;
  const DoctorPatientLoaded({required this.patient, required this.diagnoses, required this.prescriptions, required this.labReports});
  @override List<Object?> get props => [patient];
}

class DoctorAiAnalysisResult extends DoctorState {
  final AiAnalysisResult result;
  const DoctorAiAnalysisResult({required this.result});
  @override List<Object?> get props => [result];
}

class DoctorActionSuccess extends DoctorState {
  final String message;
  const DoctorActionSuccess({required this.message});
  @override List<Object?> get props => [message];
}

class DoctorError extends DoctorState {
  final String message;
  const DoctorError({required this.message});
  @override List<Object?> get props => [message];
}

// ─── BLoC ───
class DoctorBloc extends Bloc<DoctorEvent, DoctorState> {
  final _supabase = Supabase.instance.client;

  DoctorBloc() : super(DoctorInitial()) {
    on<DoctorLoadDashboard>(_onLoadDashboard);
    on<DoctorLoadPatient>(_onLoadPatient);
    on<DoctorCreateLabRequest>(_onCreateLabRequest);
    on<DoctorCreatePrescription>(_onCreatePrescription);
    on<DoctorAnalyzePrescription>(_onAnalyzePrescription);
    on<DoctorCreateDiagnosis>(_onCreateDiagnosis);
  }

  Future<void> _onLoadDashboard(DoctorLoadDashboard event, Emitter<DoctorState> emit) async {
    emit(DoctorLoading());
    try {
      final results = await Future.wait([
        _supabase.from('patients').select('patient_id, name, health_status').limit(10),
        _supabase.from('diagnosis').select('*, patients(name)').eq('doctor_id', event.doctorId).order('created_at', ascending: false).limit(5),
      ]);
      emit(DoctorDashboardLoaded(
        recentPatients: List<Map<String, dynamic>>.from(results[0] as List),
        recentDiagnoses: List<Map<String, dynamic>>.from(results[1] as List),
      ));
    } catch (e) {
      emit(DoctorError(message: e.toString()));
    }
  }

  Future<void> _onLoadPatient(DoctorLoadPatient event, Emitter<DoctorState> emit) async {
    emit(DoctorLoading());
    // Honeypatient guard
    final guard = await HoneypatientGuard.guard(
      patientId: event.patientId,
      accessorId: event.doctorId,
      accessorRole: 'doctor',
      action: 'VIEW_PATIENT',
    );
    if (!guard.allowed) { emit(const DoctorError(message: 'Access denied')); return; }

    try {
      final results = await Future.wait([
        _supabase.from('patients').select('*').eq('patient_id', event.patientId).single(),
        _supabase.from('diagnosis').select('*').eq('patient_id', event.patientId).order('created_at', ascending: false),
        _supabase.from('prescriptions').select('*').eq('patient_id', event.patientId).order('created_at', ascending: false),
        _supabase.from('lab_reports').select('*, lab_requests!inner(patient_id)').eq('lab_requests.patient_id', event.patientId),
      ]);
      emit(DoctorPatientLoaded(
        patient: results[0] as Map<String, dynamic>,
        diagnoses: List<Map<String, dynamic>>.from(results[1] as List),
        prescriptions: List<Map<String, dynamic>>.from(results[2] as List),
        labReports: List<Map<String, dynamic>>.from(results[3] as List),
      ));
    } catch (e) {
      emit(DoctorError(message: e.toString()));
    }
  }

  Future<void> _onCreateLabRequest(DoctorCreateLabRequest event, Emitter<DoctorState> emit) async {
    try {
      await _supabase.from('lab_requests').insert({
        'patient_id': event.patientId,
        'doctor_id': event.doctorId,
        'test_type': event.testType,
        'notes': event.notes,
        'urgency': event.urgency,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      // Notify patient
      await _supabase.rpc('notify_user_by_patient_id', params: {
        'p_patient_id': event.patientId,
        'p_type': 'lab_request',
        'p_message': 'Dr. requested a lab test: ${event.testType}. Please approve or reject.',
        'p_metadata': {'test_type': event.testType, 'doctor_id': event.doctorId},
      });
      emit(const DoctorActionSuccess(message: 'Lab request created. Patient notified.'));
    } catch (e) {
      emit(DoctorError(message: e.toString()));
    }
  }

  Future<void> _onCreatePrescription(DoctorCreatePrescription event, Emitter<DoctorState> emit) async {
    try {
      await _supabase.from('prescriptions').insert({
        'patient_id': event.patientId,
        'doctor_id': event.doctorId,
        'medicines': event.medicines,
        'instructions': event.instructions,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      // Notify patient
      await _supabase.rpc('notify_user_by_patient_id', params: {
        'p_patient_id': event.patientId,
        'p_type': 'prescription_generated',
        'p_message': 'A new prescription has been issued. Visit pharmacy to collect.',
        'p_metadata': {'medicines': event.medicines},
      });
      emit(const DoctorActionSuccess(message: 'Prescription created successfully'));
    } catch (e) {
      emit(DoctorError(message: e.toString()));
    }
  }

  Future<void> _onAnalyzePrescription(DoctorAnalyzePrescription event, Emitter<DoctorState> emit) async {
    emit(DoctorLoading());
    try {
      final result = await AiService.analyzePrescription(
        medicines: event.medicines,
        diagnoses: event.diagnoses,
        medicalHistory: event.history,
      );
      emit(DoctorAiAnalysisResult(result: result));
    } catch (e) {
      emit(DoctorError(message: 'AI analysis failed: $e'));
    }
  }

  Future<void> _onCreateDiagnosis(DoctorCreateDiagnosis event, Emitter<DoctorState> emit) async {
    try {
      await _supabase.from('diagnosis').insert({
        'patient_id': event.patientId,
        'doctor_id': event.doctorId,
        'diagnosis': event.diagnosis,
        'notes': event.notes,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _supabase.rpc('notify_user_by_patient_id', params: {
        'p_patient_id': event.patientId,
        'p_type': 'diagnosis_updated',
        'p_message': 'Your doctor has updated your diagnosis.',
        'p_metadata': {},
      });
      emit(const DoctorActionSuccess(message: 'Diagnosis created successfully'));
    } catch (e) {
      emit(DoctorError(message: e.toString()));
    }
  }
}

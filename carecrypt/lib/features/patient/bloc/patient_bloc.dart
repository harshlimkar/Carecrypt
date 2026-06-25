import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/honeypatient_guard.dart';
import '../../../core/services/ai_service.dart';
import '../models/patient_models.dart';

// ─── Events ───
abstract class PatientEvent extends Equatable {
  const PatientEvent();
  @override
  List<Object?> get props => [];
}

class PatientLoadDashboard extends PatientEvent {
  final String patientId;
  final String userId;
  const PatientLoadDashboard({required this.patientId, required this.userId});
  @override
  List<Object?> get props => [patientId, userId];
}

class PatientApproveLabRequest extends PatientEvent {
  final String requestId;
  final String patientId;
  const PatientApproveLabRequest({required this.requestId, required this.patientId});
  @override
  List<Object?> get props => [requestId, patientId];
}

class PatientRejectLabRequest extends PatientEvent {
  final String requestId;
  const PatientRejectLabRequest({required this.requestId});
  @override
  List<Object?> get props => [requestId];
}

class PatientLoadNotifications extends PatientEvent {
  final String userId;
  const PatientLoadNotifications({required this.userId});
  @override
  List<Object?> get props => [userId];
}

// ─── States ───
abstract class PatientState extends Equatable {
  const PatientState();
  @override
  List<Object?> get props => [];
}

class PatientInitial extends PatientState {}
class PatientLoading extends PatientState {}

class PatientDashboardLoaded extends PatientState {
  final PatientProfile profile;
  final List<Diagnosis> diagnoses;
  final List<Prescription> prescriptions;
  final List<LabReport> labReports;
  final List<NurseLog> nurseLogs;
  final List<AccessLog> accessLogs;
  final List<AiSafetyScore> aiScores;
  final HealthMetrics metrics;

  const PatientDashboardLoaded({
    required this.profile,
    required this.diagnoses,
    required this.prescriptions,
    required this.labReports,
    required this.nurseLogs,
    required this.accessLogs,
    required this.aiScores,
    required this.metrics,
  });

  @override
  List<Object?> get props => [profile, diagnoses, prescriptions];
}

class PatientNotificationsLoaded extends PatientState {
  final List<AppNotification> notifications;
  const PatientNotificationsLoaded({required this.notifications});
  @override
  List<Object?> get props => [notifications];
}

class PatientError extends PatientState {
  final String message;
  const PatientError({required this.message});
  @override
  List<Object?> get props => [message];
}

class PatientActionSuccess extends PatientState {
  final String message;
  const PatientActionSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───
class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final _supabase = Supabase.instance.client;

  PatientBloc() : super(PatientInitial()) {
    on<PatientLoadDashboard>(_onLoadDashboard);
    on<PatientApproveLabRequest>(_onApproveLabRequest);
    on<PatientRejectLabRequest>(_onRejectLabRequest);
    on<PatientLoadNotifications>(_onLoadNotifications);
  }

  Future<void> _onLoadDashboard(PatientLoadDashboard event, Emitter<PatientState> emit) async {
    emit(PatientLoading());
    try {
      // Security: Check for honeypatient access
      final guard = await HoneypatientGuard.guard(
        patientId: event.patientId,
        accessorId: event.userId,
        accessorRole: 'patient',
        action: 'VIEW_DASHBOARD',
      );
      if (!guard.allowed) {
        emit(const PatientError(message: 'Access denied'));
        return;
      }

      // Parallel fetch all patient data
      final results = await Future.wait([
        _supabase.from('patients').select('*').eq('patient_id', event.patientId).single(),
        _supabase.from('diagnosis').select('*').eq('patient_id', event.patientId).order('created_at', ascending: false),
        _supabase.from('prescriptions').select('*').eq('patient_id', event.patientId).order('created_at', ascending: false),
        _supabase.from('lab_reports').select('*, lab_requests!inner(patient_id)').eq('lab_requests.patient_id', event.patientId).order('created_at', ascending: false),
        _supabase.from('nurse_logs').select('*').eq('patient_id', event.patientId).order('timestamp', ascending: false).limit(10),
        _supabase.from('access_logs').select('*').eq('patient_id', event.patientId).order('timestamp', ascending: false).limit(20),
        _supabase.from('ai_analysis').select('*').eq('patient_id', event.patientId).order('created_at', ascending: false).limit(1),
      ]);

      final profileData = results[0] as Map<String, dynamic>;
      final diagnosesData = results[1] as List<dynamic>;
      final prescriptionsData = results[2] as List<dynamic>;
      final reportsData = results[3] as List<dynamic>;
      final nurseLogsData = results[4] as List<dynamic>;
      final accessLogsData = results[5] as List<dynamic>;
      final aiData = results[6] as List<dynamic>;

      // Parse AI scores from latest analysis
      List<AiSafetyScore> aiScores = [];
      if (aiData.isNotEmpty) {
        final scores = aiData.first['safety_scores'] as List<dynamic>? ?? [];
        aiScores = scores.map((s) => AiSafetyScore(
          medicine: s['medicine'] as String,
          safetyPercent: (s['safety_percent'] as num).toDouble(),
          riskLevel: s['risk_level'] as String,
          warnings: List<String>.from(s['warnings'] as List? ?? []),
          recommendation: s['recommendation'] as String? ?? '',
        )).toList();
      }

      emit(PatientDashboardLoaded(
        profile: PatientProfile.fromJson(profileData),
        diagnoses: diagnosesData.map((d) => Diagnosis.fromJson(d as Map<String, dynamic>)).toList(),
        prescriptions: prescriptionsData.map((p) => Prescription.fromJson(p as Map<String, dynamic>)).toList(),
        labReports: reportsData.map((r) => LabReport.fromJson(r as Map<String, dynamic>)).toList(),
        nurseLogs: nurseLogsData.map((n) => NurseLog.fromJson(n as Map<String, dynamic>)).toList(),
        accessLogs: accessLogsData.map((a) => AccessLog.fromJson(a as Map<String, dynamic>)).toList(),
        aiScores: aiScores,
        metrics: HealthMetrics.fromJson(profileData),
      ));
    } catch (e) {
      emit(PatientError(message: e.toString()));
    }
  }

  Future<void> _onApproveLabRequest(PatientApproveLabRequest event, Emitter<PatientState> emit) async {
    try {
      await _supabase.from('lab_requests').update({
        'status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', event.requestId);

      // Try to notify lab via RPC — non-critical if it doesn't exist
      try {
        await _supabase.rpc('notify_lab_request_approved', params: {
          'request_id': event.requestId,
          'patient_id': event.patientId,
        });
      } catch (_) {
        // RPC may not exist in all environments — direct update is sufficient
        // The lab dashboard polls for status='approved' on refresh
      }

      // Mark this notification as read
      try {
        await _supabase
            .from('notifications')
            .update({'read': true})
            .eq('user_id', _supabase.auth.currentUser?.id ?? '')
            .contains('metadata', {'request_id': event.requestId});
      } catch (_) {}

      emit(const PatientActionSuccess(message: 'Lab test approved! The lab will now process your request.'));
    } catch (e) {
      emit(PatientError(message: e.toString()));
    }
  }

  Future<void> _onRejectLabRequest(PatientRejectLabRequest event, Emitter<PatientState> emit) async {
    try {
      await _supabase.from('lab_requests').update({
        'status': 'rejected',
      }).eq('id', event.requestId);
      emit(const PatientActionSuccess(message: 'Lab request rejected'));
    } catch (e) {
      emit(PatientError(message: e.toString()));
    }
  }

  Future<void> _onLoadNotifications(PatientLoadNotifications event, Emitter<PatientState> emit) async {
    try {
      final data = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', event.userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = (data as List<dynamic>)
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();

      emit(PatientNotificationsLoaded(notifications: notifications));
    } catch (e) {
      emit(PatientError(message: e.toString()));
    }
  }
}

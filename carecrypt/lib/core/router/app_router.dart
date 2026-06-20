import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/patient/screens/patient_dashboard.dart';
import '../../features/patient/screens/patient_records.dart';
import '../../features/patient/screens/patient_qr.dart';
import '../../features/patient/screens/patient_notifications.dart';
import '../../features/patient/screens/patient_access_log.dart';
import '../../features/doctor/screens/doctor_dashboard.dart';
import '../../features/doctor/screens/doctor_patient_access.dart';
import '../../features/doctor/screens/doctor_lab_request.dart';
import '../../features/doctor/screens/doctor_prescription.dart';
import '../../features/lab/screens/lab_dashboard.dart';
import '../../features/pharmacy/screens/pharmacy_scanner.dart';
import '../../features/nurse/screens/nurse_nfc.dart';
import '../constants/app_constants.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final authBloc = context.read<AuthBloc>();
      final isLoggedIn = authBloc.state is AuthAuthenticated;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isLogin = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isSplash && !isLogin) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Patient ─────────────────────────────────
      GoRoute(path: AppRoutes.patientDashboard, builder: (_, __) => const PatientDashboard()),
      GoRoute(path: AppRoutes.patientRecords, builder: (_, __) => const PatientRecordsScreen()),
      GoRoute(path: AppRoutes.patientQr, builder: (_, __) => const PatientQrScreen()),
      GoRoute(path: AppRoutes.patientNotifications, builder: (_, __) => const PatientNotificationsScreen()),
      GoRoute(path: AppRoutes.patientAccessLog, builder: (_, __) => const PatientAccessLogScreen()),

      // ── Doctor ──────────────────────────────────
      GoRoute(path: AppRoutes.doctorDashboard, builder: (_, __) => const DoctorDashboard()),
      GoRoute(path: AppRoutes.doctorPatientAccess, builder: (_, s) => DoctorPatientAccessScreen(patientId: s.uri.queryParameters['patientId'] ?? '')),
      GoRoute(path: AppRoutes.doctorLabRequest, builder: (_, s) => DoctorLabRequestScreen(patientId: s.uri.queryParameters['patientId'] ?? '')),
      GoRoute(path: AppRoutes.doctorPrescription, builder: (_, s) => DoctorPrescriptionScreen(patientId: s.uri.queryParameters['patientId'] ?? '')),

      // ── Lab ─────────────────────────────────────
      GoRoute(path: AppRoutes.labDashboard, builder: (_, __) => const LabDashboard()),
      GoRoute(path: AppRoutes.labUploadReport, builder: (_, s) => LabUploadReportScreen(requestId: s.uri.queryParameters['requestId'] ?? '', patientId: s.uri.queryParameters['patientId'] ?? '')),

      // ── Pharmacy ────────────────────────────────
      GoRoute(path: AppRoutes.pharmacyScanner, builder: (_, __) => const PharmacyScannerScreen()),
      GoRoute(path: AppRoutes.pharmacyPrescriptionDetail, builder: (_, s) => PharmacyPrescriptionDetailScreen(prescriptionId: s.uri.queryParameters['id'] ?? '')),

      // ── Nurse ───────────────────────────────────
      GoRoute(path: AppRoutes.nurseNfc, builder: (_, __) => const NurseNfcScreen()),
      GoRoute(path: AppRoutes.nurseTreatment, builder: (_, s) => NurseTreatmentScreen(patientId: s.uri.queryParameters['patientId'] ?? '')),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
}
